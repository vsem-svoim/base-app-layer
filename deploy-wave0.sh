#!/bin/bash
set -euo pipefail

# Wave 0 Deployment Script
# Deploys core foundation services: ArgoCD, Cert-Manager, AWS LB Controller, Vault

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validation functions
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl."
        exit 1
    fi
    log_info "kubectl found"
}

check_cluster() {
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    log_info "Connected to cluster: $(kubectl config current-context)"
}

wait_for_pods() {
    local namespace=$1
    local timeout=${2:-300}
    
    log_info "Waiting for pods in namespace $namespace (timeout: ${timeout}s)"
    kubectl wait --for=condition=ready pod --all -n "$namespace" --timeout="${timeout}s" || {
        log_error "Pods in $namespace not ready within ${timeout}s"
        return 1
    }
    log_info "All pods in $namespace are ready"
}

# Deployment functions
deploy_argocd() {
    log_info "Deploying ArgoCD..."
    
    kubectl create namespace argocd || log_warn "ArgoCD namespace already exists"
    
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    wait_for_pods "argocd" 300
    
    # Get admin password
    local admin_password
    admin_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    log_info "ArgoCD admin password: $admin_password"
    
    log_info "ArgoCD deployed successfully"
}

deploy_cert_manager() {
    log_info "Deploying cert-manager..."
    
    kubectl create namespace cert-manager || log_warn "cert-manager namespace already exists"
    
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
    
    wait_for_pods "cert-manager" 180
    
    log_info "cert-manager deployed successfully"
}

deploy_aws_lb_controller() {
    log_info "Deploying AWS Load Balancer Controller..."
    
    # Check if using local manifests
    if [[ -f "platform-services-v2/core-services/aws-load-balancer-controller/kustomization.yaml" ]]; then
        kubectl apply -k platform-services-v2/core-services/aws-load-balancer-controller
    else
        log_warn "Local AWS LB Controller manifests not found, using minimal deployment"
        kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.6.0/docs/install/iam_policy.json
    fi
    
    # Wait for controller pods
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=aws-load-balancer-controller -n kube-system --timeout=180s || {
        log_warn "AWS LB Controller pods not ready, continuing..."
    }
    
    log_info "AWS Load Balancer Controller deployed"
}

deploy_vault() {
    log_info "Deploying Vault..."
    
    # Force cleanup any existing vault namespace with timeout
    if kubectl get namespace vault &> /dev/null; then
        log_info "Cleaning up existing vault namespace..."
        kubectl delete namespace vault --force --grace-period=0 &> /dev/null || true
        kubectl patch namespace vault -p '{"metadata":{"finalizers":[]}}' --type=merge &> /dev/null || true
        
        # Wait with timeout (max 30 seconds)
        local timeout=15
        local count=0
        while kubectl get namespace vault &> /dev/null && [ $count -lt $timeout ]; do
            log_info "Waiting for vault namespace cleanup... ($count/$timeout)"
            sleep 2
            ((count++))
        done
        
        # If still stuck, force finalize and continue
        if kubectl get namespace vault &> /dev/null; then
            log_warn "Namespace stuck, continuing anyway..."
            kubectl get namespace vault -o json | jq '.spec.finalizers = []' | kubectl replace --raw "/api/v1/namespaces/vault/finalize" -f - &> /dev/null || true
        fi
    fi
    
    # Create namespace (will succeed even if old one is terminating)
    kubectl create namespace vault 2>/dev/null || kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: vault
EOF
    
    # Deploy minimal Vault (avoid Helm complications)
    cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vault
  namespace: vault
  labels:
    app: vault
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vault
  template:
    metadata:
      labels:
        app: vault
    spec:
      containers:
      - name: vault
        image: hashicorp/vault:1.20.2
        ports:
        - containerPort: 8200
        env:
        - name: VAULT_ADDR
          value: "http://127.0.0.1:8200"
        - name: VAULT_API_ADDR
          value: "http://0.0.0.0:8200"
        command: ["vault", "server", "-config=/vault/config/config.hcl"]
        readinessProbe:
          httpGet:
            path: /v1/sys/health?standbyok=true&sealedcode=200&uninitcode=200
            port: 8200
            scheme: HTTP
          initialDelaySeconds: 15
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 5
        livenessProbe:
          httpGet:
            path: /v1/sys/health?standbyok=true&sealedcode=200&uninitcode=200
            port: 8200
            scheme: HTTP
          initialDelaySeconds: 60
          periodSeconds: 30
          timeoutSeconds: 5
          failureThreshold: 3
        volumeMounts:
        - name: vault-data
          mountPath: /vault/data
        - name: vault-config
          mountPath: /vault/config
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: vault-data
        emptyDir: {}
      - name: vault-config
        configMap:
          name: vault-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: vault-config
  namespace: vault
data:
  config.hcl: |
    storage "file" {
      path = "/vault/data"
    }
    listener "tcp" {
      address = "0.0.0.0:8200"
      tls_disable = 1
    }
    disable_mlock = true
    ui = true
  init.sh: |
    #!/bin/bash
    set -euo pipefail
    
    # Production-grade Vault initialization script
    VAULT_URL="http://vault.vault.svc.cluster.local:8200"
    MAX_RETRIES=60
    RETRY_DELAY=5
    
    echo "Starting Vault initialization process..."
    
    # Wait for Vault service to be available
    echo "Waiting for Vault service at $VAULT_URL..."
    for i in $(seq 1 $MAX_RETRIES); do
      if curl -sf "$VAULT_URL/v1/sys/health" >/dev/null 2>&1; then
        echo "Vault service is responding (attempt $i/$MAX_RETRIES)"
        break
      fi
      if [ $i -eq $MAX_RETRIES ]; then
        echo "ERROR: Vault service not available after $MAX_RETRIES attempts"
        exit 1
      fi
      echo "Vault not ready, waiting... (attempt $i/$MAX_RETRIES)"
      sleep $RETRY_DELAY
    done
    
    # Check if already initialized
    echo "Checking Vault initialization status..."
    INIT_STATUS=$(curl -sf "$VAULT_URL/v1/sys/init" || echo '{"initialized":false}')
    
    if echo "$INIT_STATUS" | grep -q '"initialized":true'; then
      echo "Vault is already initialized, skipping initialization"
      exit 0
    fi
    
    # Initialize Vault
    echo "Initializing Vault with 5 key shares, threshold 3..."
    INIT_RESPONSE=$(curl -sf -X POST \
      -H "Content-Type: application/json" \
      -d '{"key_shares":5,"key_threshold":3}' \
      "$VAULT_URL/v1/sys/init")
    
    if [ $? -ne 0 ]; then
      echo "ERROR: Failed to initialize Vault"
      exit 1
    fi
    
    # Validate response
    if ! echo "$INIT_RESPONSE" | grep -q '"keys_base64"'; then
      echo "ERROR: Invalid initialization response"
      echo "Response: $INIT_RESPONSE"
      exit 1
    fi
    
    # Extract and store keys
    echo "Extracting unseal keys and root token..."
    echo "$INIT_RESPONSE" | jq -r '.keys_base64[]' > /tmp/unseal-keys
    echo "$INIT_RESPONSE" | jq -r '.root_token' > /tmp/root-token
    
    # Create Kubernetes secret
    echo "Storing keys in Kubernetes secret..."
    kubectl create secret generic vault-keys -n vault \
      --from-file=unseal-keys=/tmp/unseal-keys \
      --from-file=root-token=/tmp/root-token \
      --dry-run=client -o yaml | kubectl apply -f -
    
    echo "✅ Vault initialization completed successfully"
  unseal.sh: |
    #!/bin/bash
    set -euo pipefail
    
    # Production-grade Vault unsealing script
    VAULT_URL="http://vault.vault.svc.cluster.local:8200"
    MAX_RETRIES=60
    RETRY_DELAY=5
    
    echo "Starting Vault unsealing process..."
    
    # Wait for Vault to be responsive
    echo "Waiting for Vault service at $VAULT_URL..."
    for i in $(seq 1 $MAX_RETRIES); do
      if curl -sf "$VAULT_URL/v1/sys/health" >/dev/null 2>&1; then
        echo "Vault service is responding (attempt $i/$MAX_RETRIES)"
        break
      fi
      if [ $i -eq $MAX_RETRIES ]; then
        echo "ERROR: Vault service not available after $MAX_RETRIES attempts"
        exit 1
      fi
      echo "Vault not ready, waiting... (attempt $i/$MAX_RETRIES)"
      sleep $RETRY_DELAY
    done
    
    # Check seal status
    echo "Checking Vault seal status..."
    SEAL_STATUS=$(curl -sf "$VAULT_URL/v1/sys/seal-status" || echo '{"sealed":true}')
    
    if echo "$SEAL_STATUS" | grep -q '"sealed":false'; then
      echo "Vault is already unsealed"
      exit 0
    fi
    
    # Wait for vault-keys secret to exist
    echo "Waiting for vault-keys secret..."
    for i in $(seq 1 30); do
      if kubectl get secret vault-keys -n vault >/dev/null 2>&1; then
        echo "vault-keys secret found"
        break
      fi
      if [ $i -eq 30 ]; then
        echo "ERROR: vault-keys secret not found after 30 attempts"
        exit 1
      fi
      echo "Waiting for vault-keys secret... (attempt $i/30)"
      sleep 2
    done
    
    # Get unseal keys
    echo "Retrieving unseal keys..."
    kubectl get secret vault-keys -n vault -o jsonpath='{.data.unseal-keys}' | base64 -d > /tmp/unseal-keys
    
    if [ ! -s /tmp/unseal-keys ]; then
      echo "ERROR: No unseal keys found in secret"
      exit 1
    fi
    
    # Unseal with first 3 keys
    echo "Unsealing Vault..."
    KEY_COUNT=0
    while read -r key && [ $KEY_COUNT -lt 3 ]; do
      if [ -n "$key" ]; then
        echo "Using unseal key $((KEY_COUNT + 1))/3..."
        UNSEAL_RESPONSE=$(curl -sf -X POST \
          -H "Content-Type: application/json" \
          -d "{\"key\":\"$key\"}" \
          "$VAULT_URL/v1/sys/unseal")
        
        if echo "$UNSEAL_RESPONSE" | grep -q '"sealed":false'; then
          echo "✅ Vault unsealed successfully"
          exit 0
        fi
        
        KEY_COUNT=$((KEY_COUNT + 1))
      fi
    done < /tmp/unseal-keys
    
    # Final status check
    FINAL_STATUS=$(curl -sf "$VAULT_URL/v1/sys/seal-status")
    if echo "$FINAL_STATUS" | grep -q '"sealed":false'; then
      echo "✅ Vault unsealing completed successfully"
    else
      echo "ERROR: Vault unsealing failed"
      echo "Final status: $FINAL_STATUS"
      exit 1
    fi
---
apiVersion: v1
kind: Service
metadata:
  name: vault
  namespace: vault
  labels:
    app: vault
spec:
  selector:
    app: vault
  ports:
  - port: 8200
    targetPort: 8200
  type: ClusterIP
EOF
    
    wait_for_pods "vault" 120
    
    # Deploy ServiceAccount and RBAC for later Job use
    log_info "Creating ServiceAccount and RBAC for Vault automation..."
    cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: vault-init
  namespace: vault
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: vault-init
  namespace: vault
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["create", "get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: vault-init
  namespace: vault
subjects:
- kind: ServiceAccount
  name: vault-init
  namespace: vault
roleRef:
  kind: Role
  name: vault-init
  apiGroup: rbac.authorization.k8s.io
EOF

    # Wait for RBAC to propagate
    sleep 5
    
    # Wait for Vault service to be responding before creating Jobs
    log_info "Waiting for Vault service to be ready before creating automation Jobs..."
    VAULT_SERVICE_URL="http://vault.vault.svc.cluster.local:8200"
    
    # First, let's diagnose what's actually happening
    log_info "🔍 Diagnosing Vault deployment status..."
    log_info "Pod status:"
    kubectl get pods -n vault -o wide
    log_info "Service status:"
    kubectl get svc -n vault -o wide
    log_info "Service endpoints:"
    kubectl get endpoints -n vault
    log_info "Pod logs (last 20 lines):"
    kubectl logs -n vault --tail=20 deployment/vault || log_warn "Could not get logs"
    
    for i in $(seq 1 60); do  # Increased to 60 attempts (10 minutes)
        log_info "🔬 Attempt $i/60: Testing Vault connectivity..."
        
        # Test 1: Basic connectivity to service
        if kubectl exec -n vault deployment/vault -- curl -f "http://localhost:8200/v1/sys/health?standbyok=true&sealedcode=200&uninitcode=200" 2>/dev/null; then
            log_info "✅ Vault localhost health check passed"
            
            # Test 2: Service DNS resolution
            if nslookup vault.vault.svc.cluster.local >/dev/null 2>&1; then
                log_info "✅ DNS resolution working"
                
                # Test 3: Service connectivity from external
                if curl -sf "$VAULT_SERVICE_URL/v1/sys/health?standbyok=true&sealedcode=200&uninitcode=200" >/dev/null 2>&1; then
                    log_info "✅ Vault service is responding, proceeding with automation Jobs"
                    break
                else
                    log_warn "❌ External service connectivity failed"
                fi
            else
                log_warn "❌ DNS resolution failed for vault.vault.svc.cluster.local"
            fi
        else
            log_warn "❌ Vault localhost health check failed"
            log_info "Current Vault status:"
            kubectl exec -n vault deployment/vault -- curl -s "http://localhost:8200/v1/sys/health" 2>/dev/null || log_warn "No response from Vault"
        fi
        
        if [ $i -eq 60 ]; then
            log_error "❌ Vault service not responding after 60 attempts (10 minutes)"
            log_error "Final diagnostics:"
            kubectl describe pods -n vault
            kubectl describe svc -n vault
            kubectl logs -n vault --tail=50 deployment/vault
            return 1
        fi
        
        log_info "⏳ Waiting for Vault service... (attempt $i/60)"
        sleep 10
    done
    
    # Clean up any existing Jobs first (Jobs are immutable)
    log_info "Cleaning up any existing Vault Jobs..."
    kubectl delete job vault-init vault-unseal -n vault --ignore-not-found=true
    
    # Wait for cleanup
    sleep 2
    
    # Now deploy the Jobs (Vault service is confirmed working)
    log_info "Deploying Vault automation Jobs..."
    cat <<'EOF' | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: vault-init
  namespace: vault
spec:
  template:
    spec:
      serviceAccountName: vault-init
      containers:
      - name: vault-init
        image: alpine/k8s:1.28.2
        command: ["/bin/bash", "/scripts/init.sh"]
        volumeMounts:
        - name: init-scripts
          mountPath: /scripts
      volumes:
      - name: init-scripts
        configMap:
          name: vault-config
          defaultMode: 0755
      restartPolicy: OnFailure
  backoffLimit: 3
---
apiVersion: batch/v1
kind: Job
metadata:
  name: vault-unseal
  namespace: vault
spec:
  template:
    spec:
      serviceAccountName: vault-init
      containers:
      - name: vault-unseal
        image: alpine/k8s:1.28.2
        command: ["/bin/bash", "/scripts/unseal.sh"]
        volumeMounts:
        - name: unseal-scripts
          mountPath: /scripts
      volumes:
      - name: unseal-scripts
        configMap:
          name: vault-config
          defaultMode: 0755
      restartPolicy: OnFailure
  backoffLimit: 3
EOF
    
    # Let Kubernetes Jobs handle initialization and unsealing
    log_info "Starting Vault initialization and unsealing via Kubernetes Jobs..."
    
    # Wait for init job to complete
    log_info "Waiting for vault-init job to complete..."
    kubectl wait --for=condition=complete job/vault-init -n vault --timeout=300s || {
        log_warn "Vault init job did not complete, checking logs..."
        kubectl logs job/vault-init -n vault
    }
    
    # Wait for unseal job to complete
    log_info "Waiting for vault-unseal job to complete..."
    kubectl wait --for=condition=complete job/vault-unseal -n vault --timeout=300s || {
        log_warn "Vault unseal job did not complete, checking logs..."
        kubectl logs job/vault-unseal -n vault
    }
    
    # Verify Vault is ready
    sleep 5
    if curl -s "http://vault.vault.svc.cluster.local:8200/v1/sys/health?standbyok=true&sealedcode=200&uninitcode=200" | grep -q '"initialized":true'; then
        log_info "✅ Vault is initialized, unsealed, and ready"
    else
        log_error "❌ Vault health check failed"
        log_info "Checking Vault status..."
        curl -s "http://vault.vault.svc.cluster.local:8200/v1/sys/health?standbyok=true&sealedcode=200&uninitcode=200" || log_error "Health endpoint not responding"
        return 1
    fi
    
    log_info "Vault deployed, initialized, and unsealed successfully"
}

deploy_platform_ui_alb() {
    log_info "Deploying Platform UI Application Load Balancer..."
    
    # Create platform-ui namespace if it doesn't exist
    kubectl create namespace platform-ui || log_warn "platform-ui namespace already exists"
    
    # Deploy ALB Ingress for Platform UI with SSL and Route 53
    cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: platform-alb
  namespace: platform-ui
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/load-balancer-name: fin-vsem-svoim-com
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-1:084129280818:certificate/62581121-c32d-4240-a01c-226094a1f085
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    alb.ingress.kubernetes.io/healthcheck-path: /health
    alb.ingress.kubernetes.io/healthcheck-port: "80"
    alb.ingress.kubernetes.io/healthcheck-protocol: HTTP
spec:
  rules:
  - host: fin.vsem-svoim.com
    http:
      paths:
      # Platform UI (default route) - serves dashboard
      - path: /
        pathType: Prefix
        backend:
          service:
            name: platform-ui-proxy
            port:
              number: 80
EOF
    
    # Wait for ALB to be provisioned
    log_info "Waiting for ALB to be provisioned (this may take 2-3 minutes)..."
    kubectl wait --for=condition=ready ingress/platform-alb -n platform-ui --timeout=300s || {
        log_warn "ALB ingress not ready within 300s, check AWS console"
    }
    
    log_info "Platform UI ALB deployed successfully"
}

deploy_platform_ui_proxy() {
    log_info "Deploying Platform UI Proxy Service..."
    
    # Deploy Platform UI Proxy using kustomize
    kubectl apply -k platform-services-v2/application-services/platform-ui
    
    # Wait for Platform UI Proxy pods
    wait_for_pods "platform-ui" 180
    
    log_info "Platform UI Proxy deployed successfully"
}

# Validation after deployment
validate_deployment() {
    log_info "Validating Wave 0 deployment..."
    
    # Check ArgoCD
    kubectl get pods -n argocd | grep -q "Running" && log_info "✅ ArgoCD: Running" || log_error "❌ ArgoCD: Failed"
    
    # Check cert-manager
    kubectl get pods -n cert-manager | grep -q "Running" && log_info "✅ cert-manager: Running" || log_error "❌ cert-manager: Failed"
    
    # Check AWS LB Controller
    kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller | grep -q "Running" && log_info "✅ AWS LB Controller: Running" || log_warn "⚠️  AWS LB Controller: Check manually"
    
    # Check Vault
    kubectl get pods -n vault | grep -q "Running" && log_info "✅ Vault: Running" || log_error "❌ Vault: Failed"
    
    # Check Platform UI ALB
    kubectl get ingress -n platform-ui platform-alb | grep -q "platform-alb" && log_info "✅ Platform UI ALB: Deployed" || log_error "❌ Platform UI ALB: Failed"
    
    # Check Platform UI Proxy
    kubectl get pods -n platform-ui | grep -q "Running" && log_info "✅ Platform UI Proxy: Running" || log_error "❌ Platform UI Proxy: Failed"
}

# Access information
show_access_info() {
    log_info "Wave 0 Deployment Complete!"
    
    echo ""
    echo "🔐 ArgoCD Access:"
    echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "  URL: https://localhost:8080"
    echo "  Username: admin"
    echo "  Password: \$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d)"
    
    echo ""
    echo "🔑 Vault Access:"
    echo "  kubectl port-forward svc/vault -n vault 8200:8200"
    echo "  URL: http://localhost:8200"
    echo "  Token: root (dev mode)"
    
    echo ""
    echo "🌐 Platform UI Access:"
    echo "  ALB URL: \$(kubectl get ingress platform-alb -n platform-ui -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
    echo "  Direct access to ArgoCD: <ALB_URL>/argocd/"
    echo "  Direct access to Vault: <ALB_URL>/vault/"
    
    echo ""
    echo "🛑 WAVE 0 VALIDATION REQUIRED!"
    echo "================================"
    echo ""
    echo "📋 MUST TEST before Wave 1:"
    echo "  1. ✅ Platform UI Dashboard: https://fin.vsem-svoim.com/"
    echo "  2. ✅ ArgoCD Tile Access: Click ArgoCD tile in Platform UI"
    echo "  3. ✅ Vault Tile Access: Click Vault tile in Platform UI" 
    echo "  4. ✅ Vault Authentication: Use root token from vault-keys secret"
    echo "  5. ✅ SSL Certificate: Verify HTTPS redirect works"
    echo "  6. ✅ Route 53 DNS: Confirm fin.vsem-svoim.com resolves to ALB"
    echo ""
    echo "🔍 Troubleshooting Commands:"
    echo "  • Check ALB status: kubectl get ingress -n platform-ui"
    echo "  • Get Vault root token: kubectl get secret vault-keys -n vault -o jsonpath='{.data.root-token}' | base64 -d"
    echo "  • Check Vault status: kubectl exec -n vault deployment/vault -- env VAULT_ADDR=http://127.0.0.1:8200 vault status"
    echo ""
    echo "⚠️  DO NOT PROCEED TO WAVE 1 UNTIL ALL TESTS PASS!"
}

# Rollback function
rollback() {
    log_warn "Rolling back Wave 0 deployment..."
    
    # Clean up Jobs first (they prevent namespace deletion)
    kubectl delete jobs --all -n vault --ignore-not-found=true &> /dev/null &
    kubectl delete jobs --all -n argocd --ignore-not-found=true &> /dev/null &
    kubectl delete jobs --all -n cert-manager --ignore-not-found=true &> /dev/null &
    kubectl delete jobs --all -n platform-ui --ignore-not-found=true &> /dev/null &
    
    # Delete namespaces with force cleanup
    for ns in argocd cert-manager vault platform-ui; do
        if kubectl get namespace $ns &> /dev/null; then
            log_info "Cleaning up namespace: $ns"
            kubectl delete namespace $ns --force --grace-period=0 &> /dev/null &
            kubectl patch namespace $ns -p '{"metadata":{"finalizers":[]}}' --type=merge &> /dev/null &
        fi
    done
    
    # Clean up AWS LB Controller if local manifests exist
    if [[ -f "platform-services-v2/core-services/aws-load-balancer-controller/kustomization.yaml" ]]; then
        kubectl delete -k platform-services-v2/core-services/aws-load-balancer-controller &> /dev/null &
    fi
    
    # Wait a bit for cleanup
    sleep 10
    
    # Force finalize any stuck namespaces
    for ns in argocd cert-manager vault platform-ui; do
        if kubectl get namespace $ns &> /dev/null; then
            log_warn "Force finalizing stuck namespace: $ns"
            kubectl get namespace $ns -o json | jq '.spec.finalizers = []' | kubectl replace --raw "/api/v1/namespaces/$ns/finalize" -f - &> /dev/null || true
        fi
    done
    
    log_info "Rollback complete"
}

# Main deployment function
main() {
    log_info "Starting Wave 0 deployment..."
    
    # Pre-flight checks
    check_kubectl
    check_cluster
    
    # Remove error trap to avoid auto-rollback
    # trap rollback ERR
    
    # Deploy components
    deploy_argocd
    deploy_cert_manager
    deploy_aws_lb_controller
    deploy_vault
    deploy_platform_ui_alb
    deploy_platform_ui_proxy
    
    # Validate deployment
    validate_deployment
    
    # Show access information
    show_access_info
    
    log_info "Wave 0 deployment completed successfully!"
}

# Parse command line arguments
case "${1:-deploy}" in
    "deploy")
        main
        ;;
    "rollback")
        rollback
        ;;
    "validate")
        validate_deployment
        ;;
    *)
        echo "Usage: $0 [deploy|rollback|validate]"
        echo "  deploy   - Deploy Wave 0 services (default)"
        echo "  rollback - Remove all Wave 0 services"
        echo "  validate - Check Wave 0 deployment status"
        exit 1
        ;;
esac
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
    
    # Wait for any terminating vault namespace to be gone
    while kubectl get namespace vault &> /dev/null; do
        log_info "Waiting for vault namespace to be deleted..."
        sleep 5
    done
    
    kubectl create namespace vault
    
    # Deploy minimal Vault (avoid Helm complications)
    cat <<EOF | kubectl apply -f -
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
        - name: VAULT_DEV_ROOT_TOKEN_ID
          value: "root"
        - name: VAULT_DEV_LISTEN_ADDRESS
          value: "0.0.0.0:8200"
        command: ["vault", "server", "-dev"]
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
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
    
    log_info "Vault deployed successfully"
}

deploy_platform_ui_alb() {
    log_info "Deploying Platform UI Application Load Balancer..."
    
    # Create platform-ui namespace if it doesn't exist
    kubectl create namespace platform-ui || log_warn "platform-ui namespace already exists"
    
    # Deploy ALB Ingress for Platform UI
    cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: platform-alb
  namespace: platform-ui
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/load-balancer-name: base-platform-alb
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
    alb.ingress.kubernetes.io/subnets: subnet-00d893f736ab72568,subnet-0bcf6a6eaf4386574
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: "15"
    alb.ingress.kubernetes.io/healthcheck-path: /health
    alb.ingress.kubernetes.io/healthcheck-port: "80"
    alb.ingress.kubernetes.io/healthcheck-protocol: HTTP
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: "5"
    alb.ingress.kubernetes.io/healthy-threshold-count: "2"
    alb.ingress.kubernetes.io/unhealthy-threshold-count: "2"
spec:
  ingressClassName: alb
  rules:
  - http:
      paths:
      # Platform UI (default route) - deployed in Wave 0
      - path: /
        pathType: Prefix
        backend:
          service:
            name: platform-ui-proxy
            port:
              number: 80
      # ArgoCD - Wave 0 core service
      - path: /argocd
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 80
      # Vault - Wave 0 core service
      - path: /vault
        pathType: Prefix
        backend:
          service:
            name: vault
            port:
              number: 8200
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
    echo "📋 Next Steps:"
    echo "  1. Access ArgoCD via ALB and configure repositories"
    echo "  2. Deploy Wave 1 ApplicationSet"
    echo "  3. Deploy Wave 2 ApplicationSet"
}

# Rollback function
rollback() {
    log_warn "Rolling back Wave 0 deployment..."
    
    kubectl delete namespace argocd --force --grace-period=0 &
    kubectl delete namespace cert-manager --force --grace-period=0 &
    kubectl delete namespace vault --force --grace-period=0 &
    kubectl delete namespace platform-ui --force --grace-period=0 &
    kubectl delete -k platform-services-v2/core-services/aws-load-balancer-controller 2>/dev/null &
    
    wait
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
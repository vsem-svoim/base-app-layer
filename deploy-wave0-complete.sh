#!/bin/bash
# ===================================================================
# Wave 0 Deployment Script - Complete Platform Foundation
# Based on platform-services-v2 architecture
# ===================================================================

set -euo pipefail

# Configuration
REGION="${REGION:-us-east-1}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
AWS_PROFILE="${AWS_PROFILE:-akovalenko-084129280818-AdministratorAccess}"
PROJECT_NAME="base-app-layer"
CLUSTER_NAME="${PROJECT_NAME}-${ENVIRONMENT}-platform"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM_ROOT="$(cd "$SCRIPT_DIR" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Logging
log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}" >&2; }
warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }
info() { echo -e "${BLUE}[INFO] $1${NC}"; }
step() { echo -e "${PURPLE}[STEP] $1${NC}"; }

# Component tracking
DEPLOYMENT_STATUS=""
COMPONENT_HEALTH=""

# Validation functions
validate_prerequisites() {
    step "Validating Prerequisites"
    
    # Check required tools
    local required_tools="kubectl aws curl"
    for tool in $required_tools; do
        if ! command -v $tool &> /dev/null; then
            error "$tool is required but not installed"
            exit 1
        fi
    done
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    # Verify we're on the right cluster
    local current_context=$(kubectl config current-context)
    info "Connected to cluster: $current_context"
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS credentials not configured"
        exit 1
    fi
    
    info "Prerequisites validated successfully"
}

wait_for_pods() {
    local namespace=$1
    local timeout=${2:-300}
    local label_selector=${3:-""}
    
    info "Waiting for pods in namespace $namespace (timeout: ${timeout}s)"
    
    if [[ -n "$label_selector" ]]; then
        kubectl wait --for=condition=ready pod -l "$label_selector" -n "$namespace" --timeout="${timeout}s" || {
            error "Pods with selector '$label_selector' in $namespace not ready within ${timeout}s"
            return 1
        }
    else
        kubectl wait --for=condition=ready pod --all -n "$namespace" --timeout="${timeout}s" || {
            error "Pods in $namespace not ready within ${timeout}s"
            return 1
        }
    fi
    
    info "All pods in $namespace are ready"
}

check_component_health() {
    local component="$1"
    local namespace="${2:-$component}"
    
    info "Checking health for $component in namespace $namespace"
    
    case $component in
        "argocd")
            # Check if all ArgoCD pods are running and ready
            local running_pods=$(kubectl get pods -n argocd --no-headers 2>/dev/null | grep "Running" | wc -l)
            local ready_pods=$(kubectl get pods -n argocd --no-headers 2>/dev/null | awk '$2 ~ /1\/1/ {count++} END {print count+0}')
            
            if [[ $running_pods -ge 7 && $ready_pods -ge 7 ]]; then
                info "✅ ArgoCD: Running ($ready_pods/$running_pods pods ready)"
                COMPONENT_HEALTH="$COMPONENT_HEALTH $component:healthy"
            else
                error "❌ ArgoCD: Failed ($ready_pods ready, $running_pods running)"
                return 1
            fi
            ;;
        "vault")
            if kubectl get pods -n vault --no-headers 2>/dev/null | grep -q "1/1.*Running"; then
                info "✅ Vault: Running"
                COMPONENT_HEALTH="$COMPONENT_HEALTH $component:healthy"
            else
                error "❌ Vault: Failed"
                return 1
            fi
            ;;
        "cert-manager")
            local running_pods=$(kubectl get pods -n cert-manager --no-headers 2>/dev/null | grep "1/1.*Running" | wc -l)
            if [[ $running_pods -ge 3 ]]; then
                info "✅ cert-manager: Running ($running_pods pods ready)"
                COMPONENT_HEALTH="$COMPONENT_HEALTH $component:healthy"
            else
                error "❌ cert-manager: Failed ($running_pods pods ready)"
                return 1
            fi
            ;;
        "aws-load-balancer-controller")
            local running_pods=$(kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller --no-headers 2>/dev/null | grep "1/1.*Running" | wc -l)
            if [[ $running_pods -ge 1 ]]; then
                info "✅ AWS LB Controller: Running ($running_pods pods ready)"
                COMPONENT_HEALTH="$COMPONENT_HEALTH $component:healthy"
            else
                warn "⚠️  AWS LB Controller: Not ready ($running_pods pods ready)"
            fi
            ;;
        "platform-ui")
            if kubectl get pods -n platform-ui --no-headers 2>/dev/null | grep -q "1/1.*Running"; then
                info "✅ Platform UI: Running"
                COMPONENT_HEALTH="$COMPONENT_HEALTH $component:healthy"
            else
                error "❌ Platform UI: Failed"
                return 1
            fi
            ;;
    esac
}

# Core service deployment functions
deploy_argocd() {
    step "Deploying ArgoCD"
    
    # Clean up any existing ArgoCD resources
    log "Cleaning up existing ArgoCD resources..."
    kubectl delete namespace argocd --force --grace-period=0 2>/dev/null || true
    
    # Wait for namespace deletion
    while kubectl get namespace argocd 2>/dev/null; do
        info "Waiting for argocd namespace to be fully deleted..."
        sleep 5
    done
    
    # Create namespace
    kubectl create namespace argocd
    
    # Deploy ArgoCD using upstream manifests
    log "Deploying ArgoCD from upstream..."
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    # Wait for ArgoCD pods
    wait_for_pods "argocd" 300
    
    # Configure ArgoCD server for insecure access
    kubectl patch configmap argocd-cmd-params-cm -n argocd --patch '{"data":{"server.insecure":"true"}}'
    
    # Get admin password
    local admin_password
    admin_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    
    check_component_health "argocd" "argocd"
    DEPLOYMENT_STATUS="$DEPLOYMENT_STATUS argocd:deployed"
    
    info "ArgoCD admin password: $admin_password"
    log "ArgoCD deployed successfully"
}

deploy_cert_manager() {
    step "Deploying cert-manager"
    
    kubectl create namespace cert-manager || warn "cert-manager namespace already exists"
    
    # Deploy cert-manager using official manifests
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml
    
    wait_for_pods "cert-manager" 180
    
    check_component_health "cert-manager" "cert-manager"
    DEPLOYMENT_STATUS="$DEPLOYMENT_STATUS cert-manager:deployed"
    
    log "cert-manager deployed successfully"
}

deploy_aws_lb_controller() {
    step "Deploying AWS Load Balancer Controller"
    
    # Check if we have local kustomization
    if [[ -f "platform-services-v2/core-services/aws-load-balancer-controller/kustomization.yaml" ]]; then
        log "Using local AWS LB Controller manifests..."
        kubectl apply -k platform-services-v2/core-services/aws-load-balancer-controller
    else
        log "Using Helm to deploy AWS LB Controller..."
        
        # Install Helm if not present
        if ! command -v helm &> /dev/null; then
            log "Installing Helm..."
            curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
        fi
        
        # Add EKS Helm repository
        helm repo add eks https://aws.github.io/eks-charts 2>/dev/null || true
        helm repo update
        
        # Get VPC ID and cluster name
        local vpc_id
        vpc_id=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=${PROJECT_NAME}-${ENVIRONMENT}-vpc" --query "Vpcs[0].VpcId" --output text --region "$REGION")
        
        # Install AWS Load Balancer Controller
        helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
          -n kube-system \
          --set clusterName="$CLUSTER_NAME" \
          --set serviceAccount.create=true \
          --set serviceAccount.name=aws-load-balancer-controller \
          --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="arn:aws:iam::084129280818:role/${PROJECT_NAME}-${ENVIRONMENT}-platform-aws_load_balancer_controller-irsa" \
          --set nodeSelector."eks\.amazonaws\.com/nodegroup"=platform_system \
          --set region="$REGION" \
          --set vpcId="$vpc_id"
    fi
    
    # Wait for controller pods
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=aws-load-balancer-controller -n kube-system --timeout=180s || {
        warn "AWS LB Controller pods not ready, continuing..."
    }
    
    check_component_health "aws-load-balancer-controller" "kube-system"
    DEPLOYMENT_STATUS="$DEPLOYMENT_STATUS aws-load-balancer-controller:deployed"
    
    log "AWS Load Balancer Controller deployed"
}

deploy_vault() {
    step "Deploying Vault"
    
    # Wait for any terminating vault namespace
    while kubectl get namespace vault &> /dev/null; do
        info "Waiting for vault namespace to be deleted..."
        sleep 5
    done
    
    kubectl create namespace vault
    
    # Check if local Vault manifests exist
    if [[ -f "platform-services-v2/core-services/vault/vault.yaml" ]]; then
        log "Using local Vault manifests..."
        kubectl apply -f platform-services-v2/core-services/vault/vault.yaml
    else
        log "Using simple Vault deployment..."
        # Deploy simple Vault for development
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
    fi
    
    wait_for_pods "vault" 120
    
    check_component_health "vault" "vault"
    DEPLOYMENT_STATUS="$DEPLOYMENT_STATUS vault:deployed"
    
    log "Vault deployed successfully"
}

deploy_platform_ui() {
    step "Deploying Platform UI"
    
    # Create namespace first
    kubectl create namespace platform-ui || warn "platform-ui namespace already exists"
    
    # Check if Platform UI manifests exist
    if [[ -f "platform-services-v2/application-services/platform-ui/kustomization.yaml" ]]; then
        log "Using local Platform UI manifests..."
        kubectl apply -k platform-services-v2/application-services/platform-ui
    elif [[ -f "platform-services-v2/application-services/platform-ui/manifests/platform-ui-proxy.yaml" ]]; then
        log "Using Platform UI proxy manifests..."
        kubectl apply -f platform-services-v2/application-services/platform-ui/manifests/platform-ui-proxy.yaml
    else
        warn "Platform UI manifests not found, skipping..."
        return 0
    fi
    
    wait_for_pods "platform-ui" 120 || {
        warn "Platform UI pods not ready, checking status..."
        kubectl get pods -n platform-ui
    }
    
    check_component_health "platform-ui" "platform-ui"
    DEPLOYMENT_STATUS="$DEPLOYMENT_STATUS platform-ui:deployed"
    
    log "Platform UI deployed successfully"
}

# GitOps configuration
setup_gitops() {
    step "Setting up GitOps Configuration"
    
    # Apply ArgoCD repositories if they exist
    if [[ -f "platform-services-v2/automation/gitops/repositories/argocd-repositories.yaml" ]]; then
        log "Configuring ArgoCD repositories..."
        kubectl apply -f platform-services-v2/automation/gitops/repositories/argocd-repositories.yaml
    fi
    
    # Apply ArgoCD projects if they exist
    if [[ -d "platform-services-v2/automation/gitops/projects/" ]]; then
        log "Configuring ArgoCD projects..."
        kubectl apply -f platform-services-v2/automation/gitops/projects/
    fi
    
    # Apply Wave 0 ApplicationSet if ready for GitOps
    if [[ -f "platform-services-v2/automation/gitops/applicationsets/wave0-core-services.yaml" ]]; then
        log "Applying Wave 0 ApplicationSet for future GitOps management..."
        kubectl apply -f platform-services-v2/automation/gitops/applicationsets/wave0-core-services.yaml || {
            warn "Wave 0 ApplicationSet failed to apply - may need repository configuration"
        }
    fi
    
    log "GitOps configuration completed"
}

# Validation and status
validate_deployment() {
    step "Validating Wave 0 Deployment"
    
    log "=== WAVE 0 COMPONENT STATUS ==="
    for component in argocd cert-manager aws-load-balancer-controller vault platform-ui; do
        if echo "$DEPLOYMENT_STATUS" | grep -q "$component:deployed"; then
            if echo "$COMPONENT_HEALTH" | grep -q "$component:healthy"; then
                echo "  ✅ $component: Deployed & Healthy"
            else
                echo "  ⚠️  $component: Deployed (health check failed)"
            fi
        else
            echo "  ❌ $component: Not deployed"
        fi
    done
    
    log "=== CLUSTER STATUS ==="
    kubectl get nodes -o wide
    
    log "=== NAMESPACES ==="
    kubectl get namespaces | grep -E "(argocd|vault|cert-manager|platform-ui)"
    
    log "=== SERVICE ENDPOINTS ==="
    kubectl get ingress --all-namespaces || echo "No ingresses found"
    kubectl get services --all-namespaces | grep -E "(argocd|vault|cert-manager|platform-ui|aws-load-balancer)" || echo "No services found"
}

show_access_info() {
    step "Access Information"
    
    # Get ArgoCD password
    local argocd_password=""
    if kubectl get secret argocd-initial-admin-secret -n argocd &>/dev/null; then
        argocd_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    fi
    
    echo ""
    echo "🔐 ArgoCD Access:"
    echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "  URL: https://localhost:8080"
    echo "  Username: admin"
    echo "  Password: $argocd_password"
    
    echo ""
    echo "🔑 Vault Access:"
    echo "  kubectl port-forward svc/vault -n vault 8200:8200"
    echo "  URL: http://localhost:8200"
    echo "  Token: root (dev mode)"
    
    # Check for Platform UI
    if kubectl get svc -n platform-ui &>/dev/null; then
        echo ""
        echo "🖥️  Platform UI Access:"
        echo "  kubectl port-forward svc/platform-ui-proxy -n platform-ui 8081:80"
        echo "  URL: http://localhost:8081"
    fi
    
    # Check for ALB
    local alb_url=""
    if kubectl get ingress --all-namespaces 2>/dev/null | grep -q "amazonaws.com"; then
        alb_url=$(kubectl get ingress --all-namespaces -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
        if [[ -n "$alb_url" && "$alb_url" != "null" ]]; then
            echo ""
            echo "🌐 Load Balancer Access:"
            echo "  URL: http://$alb_url"
        fi
    fi
    
    echo ""
    echo "📋 Next Steps:"
    echo "  1. Access ArgoCD and verify GitOps setup"
    echo "  2. Deploy Wave 1 ApplicationSet:"
    echo "     kubectl apply -f platform-services-v2/automation/gitops/applicationsets/wave1-shared-services.yaml"
    echo "  3. Deploy Wave 2 ApplicationSet:"
    echo "     kubectl apply -f platform-services-v2/automation/gitops/applicationsets/wave2-monitoring-logging.yaml"
    echo "  4. Deploy Wave 3 ApplicationSet:"
    echo "     kubectl apply -f platform-services-v2/automation/gitops/applicationsets/wave3-application-services.yaml"
}

# Rollback function
rollback() {
    warn "Rolling back Wave 0 deployment..."
    
    kubectl delete namespace argocd cert-manager vault platform-ui --force --grace-period=0 &
    
    # Remove AWS LB Controller
    if command -v helm &> /dev/null; then
        helm uninstall aws-load-balancer-controller -n kube-system &
    fi
    kubectl delete -k platform-services-v2/core-services/aws-load-balancer-controller 2>/dev/null &
    
    wait
    log "Rollback complete"
}

# Main deployment function
main() {
    log "Starting Wave 0 Deployment - Platform Foundation"
    log "Environment: $ENVIRONMENT | Region: $REGION | Cluster: $CLUSTER_NAME"
    
    validate_prerequisites
    
    # Deploy Wave 0 components in order
    deploy_argocd
    deploy_cert_manager
    deploy_aws_lb_controller
    deploy_vault
    deploy_platform_ui
    
    # Setup GitOps for future waves
    setup_gitops
    
    # Validate and show results
    validate_deployment
    show_access_info
    
    log "🎉 Wave 0 deployment completed successfully!"
    log "Platform foundation is ready for Wave 1+ deployments"
}

# Handle script arguments
case "${1:-deploy}" in
    "deploy")
        main
        ;;
    "argocd")
        log "Deploying ArgoCD only"
        validate_prerequisites
        deploy_argocd
        validate_deployment
        ;;
    "cert-manager")
        log "Deploying cert-manager only"
        validate_prerequisites
        deploy_cert_manager
        validate_deployment
        ;;
    "aws-lb")
        log "Deploying AWS Load Balancer Controller only"
        validate_prerequisites
        deploy_aws_lb_controller
        validate_deployment
        ;;
    "vault")
        log "Deploying Vault only"
        validate_prerequisites
        deploy_vault
        validate_deployment
        ;;
    "platform-ui")
        log "Deploying Platform UI only"
        validate_prerequisites
        deploy_platform_ui
        validate_deployment
        ;;
    "gitops")
        log "Setting up GitOps configuration only"
        validate_prerequisites
        setup_gitops
        ;;
    "validate")
        validate_deployment
        ;;
    "rollback")
        rollback
        ;;
    *)
        echo "Usage: $0 [deploy|argocd|cert-manager|aws-lb|vault|platform-ui|gitops|validate|rollback]"
        echo ""
        echo "Commands:"
        echo "  deploy        - Deploy all Wave 0 components (default)"
        echo "  argocd        - Deploy ArgoCD only"
        echo "  cert-manager  - Deploy cert-manager only"
        echo "  aws-lb        - Deploy AWS Load Balancer Controller only"
        echo "  vault         - Deploy Vault only"
        echo "  platform-ui   - Deploy Platform UI only"
        echo "  gitops        - Setup GitOps configuration only"
        echo "  validate      - Validate deployment status"
        echo "  rollback      - Remove all Wave 0 services"
        echo ""
        echo "Wave 0 Components:"
        echo "  - ArgoCD: GitOps continuous deployment"
        echo "  - cert-manager: TLS certificate management"
        echo "  - AWS Load Balancer Controller: ALB/NLB management"
        echo "  - Vault: Secrets management"
        echo "  - Platform UI: Unified dashboard"
        exit 1
        ;;
esac
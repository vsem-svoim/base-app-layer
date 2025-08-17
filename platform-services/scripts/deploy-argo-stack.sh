#!/bin/bash

# ===================================================================
# Argo Stack Deployment Script
# Deploys ArgoCD, Argo Workflows, Argo Rollouts and Platform Services
# ===================================================================

set -euo pipefail

# Configuration
REGION="us-east-1"
PLATFORM_CLUSTER="base-app-layer-dev-platform"
AWS_PROFILE="akovalenko-084129280818-AdministratorAccess"

# Argo versions
ARGOCD_VERSION="v3.1.0"
ARGO_WORKFLOWS_VERSION="v3.7.1"
ARGO_ROLLOUTS_VERSION="v1.8.3"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
}

warn() {
    echo -e "${YELLOW}[WARN] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed"
        exit 1
    fi
    
    if ! command -v aws &> /dev/null; then
        error "AWS CLI is not installed"
        exit 1
    fi
    
    if ! command -v helm &> /dev/null; then
        error "helm is not installed"
        exit 1
    fi
    
    info "All prerequisites satisfied"
}

# Configure kubectl for platform cluster
configure_kubectl() {
    log "Configuring kubectl for platform cluster..."
    
    export AWS_PROFILE=$AWS_PROFILE
    aws eks update-kubeconfig --region $REGION --name $PLATFORM_CLUSTER --alias platform
    
    # Test connection
    if kubectl --context=platform get nodes &> /dev/null; then
        info "Platform cluster connection successful"
        kubectl --context=platform get nodes
    else
        error "Failed to connect to platform cluster"
        exit 1
    fi
}

# Install ArgoCD
install_argocd() {
    log "Installing ArgoCD ${ARGOCD_VERSION}..."
    
    # Create namespace
    kubectl --context=platform create namespace argocd --dry-run=client -o yaml | kubectl --context=platform apply -f -
    
    # Install ArgoCD
    kubectl --context=platform apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml
    
    # Wait for ArgoCD to be ready
    info "Waiting for ArgoCD to be ready..."
    kubectl --context=platform wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
    kubectl --context=platform wait --for=condition=available --timeout=300s deployment/argocd-repo-server -n argocd
    kubectl --context=platform wait --for=condition=ready --timeout=300s pod -l app.kubernetes.io/name=argocd-application-controller -n argocd
    
    # Get ArgoCD admin password
    sleep 10  # Wait for secret to be created
    ARGOCD_PASSWORD=$(kubectl --context=platform -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    info "ArgoCD admin password: $ARGOCD_PASSWORD"
    
    log "ArgoCD installation complete"
}

# Install Argo Workflows
install_argo_workflows() {
    log "Installing Argo Workflows ${ARGO_WORKFLOWS_VERSION}..."
    
    # Create namespace
    kubectl --context=platform create namespace argo --dry-run=client -o yaml | kubectl --context=platform apply -f -
    
    # Install Argo Workflows
    kubectl --context=platform apply -f https://github.com/argoproj/argo-workflows/releases/download/${ARGO_WORKFLOWS_VERSION}/install.yaml
    
    # Wait for Argo Workflows to be ready
    info "Waiting for Argo Workflows to be ready..."
    kubectl --context=platform wait --for=condition=available --timeout=300s deployment/argo-server -n argo
    kubectl --context=platform wait --for=condition=available --timeout=300s deployment/workflow-controller -n argo
    
    log "Argo Workflows installation complete"
}

# Install Argo Rollouts
install_argo_rollouts() {
    log "Installing Argo Rollouts ${ARGO_ROLLOUTS_VERSION}..."
    
    # Create namespace
    kubectl --context=platform create namespace argo-rollouts --dry-run=client -o yaml | kubectl --context=platform apply -f -
    
    # Install Argo Rollouts
    kubectl --context=platform apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/download/${ARGO_ROLLOUTS_VERSION}/install.yaml
    
    # Wait for Argo Rollouts to be ready
    info "Waiting for Argo Rollouts to be ready..."
    kubectl --context=platform wait --for=condition=available --timeout=300s deployment/argo-rollouts -n argo-rollouts
    
    log "Argo Rollouts installation complete"
}

# Install AWS Load Balancer Controller
install_alb_controller() {
    log "Installing AWS Load Balancer Controller..."
    
    # Add Helm repo
    helm repo add eks https://aws.github.io/eks-charts
    helm repo update
    
    # Install ALB Controller
    helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
        --namespace kube-system \
        --set clusterName=$PLATFORM_CLUSTER \
        --set serviceAccount.create=true \
        --set serviceAccount.name=aws-load-balancer-controller \
        --set region=$REGION \
        --set vpcId=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=base-app-layer-dev-vpc" --query 'Vpcs[0].VpcId' --output text) \
        --wait
    
    log "AWS Load Balancer Controller installation complete"
}

# Deploy Platform UI Dashboard
deploy_platform_ui() {
    log "Deploying Platform UI Dashboard..."
    
    kubectl --context=platform apply -f ../platform-ui/dashboard.yaml
    
    # Wait for dashboard to be ready
    info "Waiting for Platform UI Dashboard to be ready..."
    kubectl --context=platform wait --for=condition=available --timeout=300s deployment/platform-ui-dashboard -n platform-ui
    
    log "Platform UI Dashboard deployment complete"
}

# Deploy Shared Applications ApplicationSet
deploy_shared_apps() {
    log "Deploying Shared Applications ApplicationSet..."
    
    # Apply the orchestration ApplicationSet
    kubectl --context=platform apply -f ../argocd/applicationsets/orchestration-apps.yaml
    
    # Apply the AWS Load Balancer Controller Application
    kubectl --context=platform apply -f ../argocd/applicationsets/aws-load-balancer-controller.yaml
    
    log "Shared Applications ApplicationSet deployment complete"
}

# Get deployment status
get_deployment_status() {
    log "Getting deployment status..."
    
    info "ArgoCD Applications:"
    kubectl --context=platform get applications -n argocd -o wide || info "No applications yet"
    
    info "ApplicationSets:"
    kubectl --context=platform get applicationsets -n argocd -o wide || info "No applicationsets yet"
    
    info "Platform Cluster Nodes:"
    kubectl --context=platform get nodes -o wide
    
    info "All Namespaces:"
    kubectl --context=platform get namespaces
    
    info "Platform Services:"
    kubectl --context=platform get ingress --all-namespaces || info "No ingresses yet"
    
    info "ArgoCD Service Endpoints:"
    kubectl --context=platform get svc -n argocd
    
    info "Platform UI Service:"
    kubectl --context=platform get svc -n platform-ui || info "Platform UI not ready yet"
}

# Deploy missing infrastructure components
deploy_infrastructure_components() {
    log "Checking and deploying missing infrastructure components..."
    
    # Install metrics-server if not present
    if ! kubectl --context=platform get deployment metrics-server -n kube-system &> /dev/null; then
        info "Installing metrics-server..."
        kubectl --context=platform apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
    fi
    
    # Create monitoring namespace for future Prometheus/Grafana
    kubectl --context=platform create namespace monitoring --dry-run=client -o yaml | kubectl --context=platform apply -f -
    
    # Create airflow namespace
    kubectl --context=platform create namespace airflow --dry-run=client -o yaml | kubectl --context=platform apply -f -
    
    # Create mlflow namespace  
    kubectl --context=platform create namespace mlflow --dry-run=client -o yaml | kubectl --context=platform apply -f -
    
    # Create kubeflow namespace
    kubectl --context=platform create namespace kubeflow --dry-run=client -o yaml | kubectl --context=platform apply -f -
    
    # Create istio-system namespace
    kubectl --context=platform create namespace istio-system --dry-run=client -o yaml | kubectl --context=platform apply -f -
    
    # Create vault namespace
    kubectl --context=platform create namespace vault --dry-run=client -o yaml | kubectl --context=platform apply -f -
    
    # Create vault-secrets-operator-system namespace
    kubectl --context=platform create namespace vault-secrets-operator-system --dry-run=client -o yaml | kubectl --context=platform apply -f -
    
    info "Infrastructure components checked/deployed"
}

# Main deployment function
main() {
    log "Starting Argo Stack and Platform Services Deployment..."
    
    check_prerequisites
    configure_kubectl
    
    # Deploy infrastructure components
    deploy_infrastructure_components
    
    # Install Argo stack
    install_argocd
    install_argo_workflows  
    install_argo_rollouts
    
    # Install supporting infrastructure
    install_alb_controller
    
    # Deploy platform services
    deploy_platform_ui
    
    # Deploy shared applications via ArgoCD
    deploy_shared_apps
    
    # Show final status
    get_deployment_status
    
    log "Argo Stack and Platform Services deployment complete!"
    info "Next steps:"
    info "1. Access ArgoCD at: kubectl port-forward svc/argocd-server -n argocd 8080:443"
    info "2. Login with admin / $(kubectl --context=platform -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)"
    info "3. Deploy BASE layer ApplicationSet when ready"
    info "4. Access Platform Dashboard when ALB is ready"
}

# Handle script arguments
case "${1:-deploy}" in
    "deploy")
        main
        ;;
    "argocd")
        check_prerequisites
        configure_kubectl
        install_argocd
        ;;
    "workflows")
        check_prerequisites
        configure_kubectl
        install_argo_workflows
        ;;
    "rollouts")
        check_prerequisites
        configure_kubectl
        install_argo_rollouts
        ;;
    "alb")
        check_prerequisites
        configure_kubectl
        install_alb_controller
        ;;
    "apps")
        check_prerequisites
        configure_kubectl
        deploy_shared_apps
        ;;
    "status")
        check_prerequisites
        configure_kubectl
        get_deployment_status
        ;;
    *)
        echo "Usage: $0 {deploy|argocd|workflows|rollouts|alb|apps|status}"
        echo "  deploy     - Full Argo stack and platform deployment"
        echo "  argocd     - Install ArgoCD only"
        echo "  workflows  - Install Argo Workflows only"
        echo "  rollouts   - Install Argo Rollouts only"
        echo "  alb        - Install AWS Load Balancer Controller only"
        echo "  apps       - Deploy shared applications only"
        echo "  status     - Show deployment status"
        exit 1
        ;;
esac
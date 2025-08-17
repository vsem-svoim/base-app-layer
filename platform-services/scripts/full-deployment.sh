#!/bin/bash

# ===================================================================
# BASE App Layer - Complete Automated Deployment Script
# Deploys entire platform: Infrastructure + GitOps + Applications
# ===================================================================

set -euo pipefail

# Configuration
REGION="${REGION:-us-east-1}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
AWS_PROFILE="${AWS_PROFILE:-akovalenko-084129280818-AdministratorAccess}"
PROJECT_NAME="base-app-layer"

# Deployment timeouts (seconds)
TERRAFORM_TIMEOUT=1800  # 30 minutes
NODE_GROUP_TIMEOUT=900  # 15 minutes
ARGOCD_TIMEOUT=600      # 10 minutes
APPLICATION_TIMEOUT=1200 # 20 minutes

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
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

step() {
    echo -e "${PURPLE}[STEP] $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    local missing_tools=()
    
    if ! command -v terraform &> /dev/null; then
        missing_tools+=("terraform")
    fi
    
    if ! command -v kubectl &> /dev/null; then
        missing_tools+=("kubectl")
    fi
    
    if ! command -v aws &> /dev/null; then
        missing_tools+=("aws")
    fi
    
    if ! command -v helm &> /dev/null; then
        missing_tools+=("helm")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_tools+=("jq")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        error "Missing required tools: ${missing_tools[*]}"
        error "Please install missing tools and try again"
        exit 1
    fi
    
    # Check AWS credentials
    export AWS_PROFILE=$AWS_PROFILE
    if ! aws sts get-caller-identity &> /dev/null; then
        error "AWS credentials not configured for profile: $AWS_PROFILE"
        exit 1
    fi
    
    info "All prerequisites satisfied"
}

# Wait for condition with timeout
wait_for_condition() {
    local condition_command="$1"
    local timeout="$2"
    local description="$3"
    local interval=30
    local elapsed=0
    
    info "Waiting for: $description (timeout: ${timeout}s)"
    
    while [ $elapsed -lt $timeout ]; do
        if eval "$condition_command" &> /dev/null; then
            info "$description - READY"
            return 0
        fi
        
        sleep $interval
        elapsed=$((elapsed + interval))
        echo -n "."
    done
    
    error "$description - TIMEOUT after ${timeout}s"
    return 1
}

# Deploy infrastructure with Terraform
deploy_infrastructure() {
    step "Step 1: Deploying Infrastructure with Terraform"
    
    cd /Users/ak/PycharmProjects/FinPortIQ/base-app-layer/platform-services/terraform-new/providers/aws/environments/dev
    
    # Initialize Terraform
    log "Initializing Terraform..."
    terraform init
    
    # Plan deployment
    log "Planning Terraform deployment..."
    terraform plan -out=tfplan
    
    # Apply infrastructure
    log "Applying Terraform infrastructure..."
    timeout $TERRAFORM_TIMEOUT terraform apply -auto-approve tfplan
    
    # Wait for EKS clusters to be ready
    wait_for_condition "aws eks describe-cluster --name $PROJECT_NAME-$ENVIRONMENT-platform --region $REGION | jq -r '.cluster.status' | grep -q ACTIVE" $NODE_GROUP_TIMEOUT "Platform cluster to be active"
    wait_for_condition "aws eks describe-cluster --name $PROJECT_NAME-$ENVIRONMENT-base --region $REGION | jq -r '.cluster.status' | grep -q ACTIVE" $NODE_GROUP_TIMEOUT "Base cluster to be active"
    
    # Wait for node groups to be ready
    info "Waiting for node groups to be ready..."
    sleep 60  # Give time for node groups to start creating
    
    # Check platform cluster node groups
    local platform_nodegroups=(platform_system platform_general platform_compute platform_memory platform_gpu)
    for nodegroup in "${platform_nodegroups[@]}"; do
        wait_for_condition "aws eks describe-nodegroup --cluster-name $PROJECT_NAME-$ENVIRONMENT-platform --nodegroup-name $nodegroup --region $REGION 2>/dev/null | jq -r '.nodegroup.status' | grep -q ACTIVE" $NODE_GROUP_TIMEOUT "Platform nodegroup $nodegroup"
    done
    
    log "Infrastructure deployment completed successfully"
}

# Configure kubectl contexts
configure_kubectl() {
    step "Step 2: Configuring kubectl contexts"
    
    # Update kubeconfig for both clusters
    aws eks update-kubeconfig --region $REGION --name $PROJECT_NAME-$ENVIRONMENT-platform --alias platform
    aws eks update-kubeconfig --region $REGION --name $PROJECT_NAME-$ENVIRONMENT-base --alias base
    
    # Test connections
    kubectl --context=platform get nodes
    kubectl --context=base get nodes
    
    log "kubectl contexts configured successfully"
}

# Deploy ArgoCD and GitOps stack
deploy_gitops_stack() {
    step "Step 3: Deploying GitOps Stack (ArgoCD, Workflows, Rollouts)"
    
    cd /Users/ak/PycharmProjects/FinPortIQ/base-app-layer/platform-services/scripts
    
    # Run ArgoCD deployment script
    ./deploy-argo-stack.sh
    
    # Wait for ArgoCD to be fully ready
    wait_for_condition "kubectl --context=platform get deployment argocd-server -n argocd -o jsonpath='{.status.readyReplicas}' | grep -q 1" $ARGOCD_TIMEOUT "ArgoCD server to be ready"
    
    log "GitOps stack deployed successfully"
}

# Deploy orchestration applications
deploy_orchestration_apps() {
    step "Step 4: Deploying Orchestration Applications"
    
    # Apply ApplicationSets
    kubectl --context=platform apply -f /Users/ak/PycharmProjects/FinPortIQ/base-app-layer/platform-services/argocd/applicationsets/
    
    # Wait for Wave 1 applications (Istio)
    wait_for_condition "kubectl --context=platform get application istio -n argocd -o jsonpath='{.status.health.status}' | grep -q Healthy" $APPLICATION_TIMEOUT "Istio (Wave 1) to be healthy"
    
    # Wait for Wave 2 applications (Vault)
    wait_for_condition "kubectl --context=platform get application vault -n argocd -o jsonpath='{.status.health.status}' | grep -q Healthy" $APPLICATION_TIMEOUT "Vault (Wave 2) to be healthy"
    
    # Wait for AWS Load Balancer Controller
    wait_for_condition "kubectl --context=platform get deployment aws-load-balancer-controller -n kube-system -o jsonpath='{.status.readyReplicas}' | grep -q 2" $APPLICATION_TIMEOUT "AWS Load Balancer Controller to be ready"
    
    log "Orchestration applications deployed successfully"
}

# Deploy Platform UI Dashboard
deploy_platform_ui() {
    step "Step 5: Deploying Platform UI Dashboard"
    
    kubectl --context=platform apply -f /Users/ak/PycharmProjects/FinPortIQ/base-app-layer/platform-services/platform-ui/dashboard.yaml
    
    # Wait for Platform UI to be ready
    wait_for_condition "kubectl --context=platform get deployment platform-ui-dashboard -n platform-ui -o jsonpath='{.status.readyReplicas}' | grep -q 2" $APPLICATION_TIMEOUT "Platform UI Dashboard to be ready"
    
    log "Platform UI Dashboard deployed successfully"
}

# Deploy BASE layer applications
deploy_base_layer() {
    step "Step 6: Deploying BASE Layer Applications"
    
    # Apply BASE layer ApplicationSet
    kubectl --context=platform apply -f /Users/ak/PycharmProjects/FinPortIQ/base-app-layer/platform-services/argocd/applicationsets/base-layer-apps.yaml
    
    # Wait for data ingestion module (first BASE module)
    wait_for_condition "kubectl --context=base get pods -n base-data-ingestion | grep -q Running" $APPLICATION_TIMEOUT "BASE data ingestion module to be running"
    
    log "BASE layer applications deployed successfully"
}

# Enable Crossplane
enable_crossplane() {
    step "Step 7: Enabling Crossplane"
    
    cd /Users/ak/PycharmProjects/FinPortIQ/base-app-layer/platform-services/terraform-new/providers/aws/environments/dev
    
    # Enable Crossplane in Terraform
    sed -i '' 's/enable_crossplane.*= false/enable_crossplane = true/' terraform.tfvars
    
    # Apply Crossplane configuration
    terraform plan -target=module.crossplane -out=crossplane-plan
    terraform apply -auto-approve crossplane-plan
    
    # Wait for Crossplane to be ready
    wait_for_condition "kubectl --context=platform get deployment crossplane -n crossplane-system -o jsonpath='{.status.readyReplicas}' | grep -q 1" $APPLICATION_TIMEOUT "Crossplane to be ready"
    
    log "Crossplane enabled successfully"
}

# Validate deployment
validate_deployment() {
    step "Step 8: Validating Deployment"
    
    log "=== CLUSTER STATUS ==="
    kubectl --context=platform get nodes -o wide
    kubectl --context=base get nodes -o wide
    
    log "=== ARGOCD APPLICATIONS ==="
    kubectl --context=platform get applications -n argocd -o wide
    
    log "=== ORCHESTRATION SERVICES ==="
    kubectl --context=platform get pods --all-namespaces | grep -E "(argocd|airflow|mlflow|kubeflow|grafana|prometheus|vault|istio)"
    
    log "=== BASE LAYER MODULES ==="
    kubectl --context=base get pods --all-namespaces | grep base-
    
    log "=== INGRESS STATUS ==="
    kubectl --context=platform get ingress --all-namespaces
    
    log "=== SERVICE ENDPOINTS ==="
    # Get ArgoCD admin password
    local argocd_password=$(kubectl --context=platform -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    
    echo -e "${GREEN}=== DEPLOYMENT COMPLETE ===${NC}"
    echo -e "${BLUE}ArgoCD Access:${NC}"
    echo "  URL: kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "  Username: admin"
    echo "  Password: $argocd_password"
    echo ""
    echo -e "${BLUE}Platform Dashboard:${NC}"
    echo "  URL: Will be available at platform.base-app-layer.dev once DNS is configured"
    echo "  ALB: $(kubectl --context=platform get ingress platform-ui-ingress -n platform-ui -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo 'Creating...')"
    echo ""
    echo -e "${BLUE}Services Available:${NC}"
    echo "  - ArgoCD (GitOps)"
    echo "  - Airflow (Workflow Orchestration)"
    echo "  - MLflow (ML Lifecycle)"
    echo "  - Kubeflow (ML Workflows)"
    echo "  - Grafana (Monitoring)"
    echo "  - Prometheus (Metrics)"
    echo "  - Vault (Secrets Management)"
    echo "  - Istio (Service Mesh)"
    echo "  - Platform UI Dashboard"
    echo ""
    echo -e "${BLUE}BASE Layer Modules:${NC}"
    echo "  - Data Ingestion (14 modules total planned)"
}

# Cleanup function
cleanup() {
    if [ $? -ne 0 ]; then
        error "Deployment failed. Check logs above for details."
        echo ""
        echo "To retry deployment:"
        echo "  ./full-deployment.sh"
        echo ""
        echo "To check status:"
        echo "  ./full-deployment.sh status"
        echo ""
        echo "To destroy everything:"
        echo "  ./full-deployment.sh destroy"
    fi
}

# Destroy deployment
destroy_deployment() {
    step "Destroying BASE App Layer Deployment"
    
    warn "This will destroy ALL infrastructure. Are you sure? (y/N)"
    read -r confirmation
    if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
        info "Destruction cancelled"
        exit 0
    fi
    
    cd /Users/ak/PycharmProjects/FinPortIQ/base-app-layer/platform-services/terraform-new/providers/aws/environments/dev
    
    # Destroy with Terraform
    terraform destroy -auto-approve
    
    log "Deployment destroyed successfully"
}

# Show status
show_status() {
    step "BASE App Layer Deployment Status"
    
    # Check if clusters exist
    if aws eks describe-cluster --name $PROJECT_NAME-$ENVIRONMENT-platform --region $REGION &> /dev/null; then
        echo -e "${GREEN}✓ Platform cluster exists${NC}"
        kubectl --context=platform get nodes
    else
        echo -e "${RED}✗ Platform cluster not found${NC}"
    fi
    
    if aws eks describe-cluster --name $PROJECT_NAME-$ENVIRONMENT-base --region $REGION &> /dev/null; then
        echo -e "${GREEN}✓ Base cluster exists${NC}"
        kubectl --context=base get nodes
    else
        echo -e "${RED}✗ Base cluster not found${NC}"
    fi
    
    # Check ArgoCD
    if kubectl --context=platform get deployment argocd-server -n argocd &> /dev/null; then
        echo -e "${GREEN}✓ ArgoCD deployed${NC}"
        kubectl --context=platform get applications -n argocd
    else
        echo -e "${RED}✗ ArgoCD not found${NC}"
    fi
}

# Main execution
main() {
    log "Starting BASE App Layer Complete Deployment"
    log "Environment: $ENVIRONMENT"
    log "Region: $REGION"
    log "AWS Profile: $AWS_PROFILE"
    
    trap cleanup EXIT
    
    check_prerequisites
    deploy_infrastructure
    configure_kubectl
    deploy_gitops_stack
    deploy_orchestration_apps
    deploy_platform_ui
    deploy_base_layer
    enable_crossplane
    validate_deployment
    
    log "🎉 BASE App Layer deployment completed successfully!"
}

# Handle script arguments
case "${1:-deploy}" in
    "deploy")
        main
        ;;
    "infrastructure")
        check_prerequisites
        deploy_infrastructure
        configure_kubectl
        ;;
    "gitops")
        check_prerequisites
        configure_kubectl
        deploy_gitops_stack
        ;;
    "apps")
        check_prerequisites
        configure_kubectl
        deploy_orchestration_apps
        deploy_platform_ui
        ;;
    "base-layer")
        check_prerequisites
        configure_kubectl
        deploy_base_layer
        ;;
    "crossplane")
        check_prerequisites
        configure_kubectl
        enable_crossplane
        ;;
    "validate")
        check_prerequisites
        configure_kubectl
        validate_deployment
        ;;
    "status")
        check_prerequisites
        show_status
        ;;
    "destroy")
        check_prerequisites
        destroy_deployment
        ;;
    *)
        echo "Usage: $0 {deploy|infrastructure|gitops|apps|base-layer|crossplane|validate|status|destroy}"
        echo ""
        echo "Commands:"
        echo "  deploy        - Full end-to-end deployment (default)"
        echo "  infrastructure - Deploy only infrastructure (Terraform)"
        echo "  gitops        - Deploy only GitOps stack (ArgoCD, etc)"
        echo "  apps          - Deploy only orchestration applications"
        echo "  base-layer    - Deploy only BASE layer applications"
        echo "  crossplane    - Enable Crossplane infrastructure platform"
        echo "  validate      - Validate and show deployment status"
        echo "  status        - Show current deployment status"
        echo "  destroy       - Destroy entire deployment"
        echo ""
        echo "Environment variables:"
        echo "  REGION        - AWS region (default: us-east-1)"
        echo "  ENVIRONMENT   - Environment name (default: dev)"
        echo "  AWS_PROFILE   - AWS profile to use"
        exit 1
        ;;
esac
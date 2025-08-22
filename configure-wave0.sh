#!/bin/bash
# ===================================================================
# Wave 0 Configuration Script - Post-Deployment Setup
# Configures ArgoCD repositories, projects, and ApplicationSets
# ===================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM_ROOT="$(cd "$SCRIPT_DIR" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}" >&2; }
warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }
info() { echo -e "${BLUE}[INFO] $1${NC}"; }

# Verify ArgoCD is running
verify_argocd() {
    info "Verifying ArgoCD is running..."
    
    if ! kubectl get pods -n argocd | grep -q "Running"; then
        error "ArgoCD is not running. Please deploy Wave 0 first."
        exit 1
    fi
    
    # Wait for ArgoCD server to be ready
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=60s
    info "ArgoCD is ready"
}

# Configure ArgoCD repositories
configure_repositories() {
    info "Configuring ArgoCD repositories..."
    
    # Apply repository configuration if exists
    if [[ -f "platform-services-v2/automation/gitops/repositories/argocd-repositories.yaml" ]]; then
        log "Applying ArgoCD repositories..."
        kubectl apply -f platform-services-v2/automation/gitops/repositories/argocd-repositories.yaml
    else
        warn "Repository configuration not found, creating default..."
        
        # Create default repository configuration
        cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: base-app-layer-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  type: git
  url: https://github.com/vsem-svoim/base-app-layer.git
  password: ""
  username: ""
EOF
    fi
    
    info "Repository configuration completed"
}

# Configure ArgoCD projects
configure_projects() {
    info "Configuring ArgoCD projects..."
    
    if [[ -d "platform-services-v2/automation/gitops/projects/" ]]; then
        log "Applying ArgoCD projects..."
        kubectl apply -f platform-services-v2/automation/gitops/projects/
    else
        warn "Project configuration not found, creating default..."
        
        # Create default project
        cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: platform-core
  namespace: argocd
spec:
  description: Platform core services project
  sourceRepos:
  - 'https://github.com/vsem-svoim/base-app-layer.git'
  destinations:
  - namespace: '*'
    server: https://kubernetes.default.svc
  clusterResourceWhitelist:
  - group: '*'
    kind: '*'
  namespaceResourceWhitelist:
  - group: '*'
    kind: '*'
EOF
    fi
    
    info "Project configuration completed"
}

# Deploy Wave ApplicationSets
deploy_application_sets() {
    info "Deploying Wave ApplicationSets..."
    
    # Deploy Wave 0 ApplicationSet (self-managing)
    if [[ -f "platform-services-v2/automation/gitops/applicationsets/wave0-core-services.yaml" ]]; then
        log "Applying Wave 0 ApplicationSet..."
        kubectl apply -f platform-services-v2/automation/gitops/applicationsets/wave0-core-services.yaml || {
            warn "Wave 0 ApplicationSet failed - may need repository access"
        }
    fi
    
    # Deploy Wave 1 ApplicationSet (ready for next phase)
    if [[ -f "platform-services-v2/automation/gitops/applicationsets/wave1-shared-services.yaml" ]]; then
        log "Applying Wave 1 ApplicationSet..."
        kubectl apply -f platform-services-v2/automation/gitops/applicationsets/wave1-shared-services.yaml || {
            warn "Wave 1 ApplicationSet failed - will be available for manual deployment"
        }
    fi
    
    info "ApplicationSets deployed"
}

# Configure RBAC and security
configure_security() {
    info "Configuring ArgoCD security and RBAC..."
    
    # Create ArgoCD admin policy
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-rbac-cm
    app.kubernetes.io/part-of: argocd
data:
  policy.default: role:readonly
  policy.csv: |
    p, role:platform-admin, applications, *, */*, allow
    p, role:platform-admin, clusters, *, *, allow
    p, role:platform-admin, repositories, *, *, allow
    g, platform-admins, role:platform-admin
EOF
    
    # Configure ArgoCD server parameters
    kubectl patch configmap argocd-cmd-params-cm -n argocd --patch '{"data":{"server.insecure":"true","server.grpc.web":"true"}}'
    
    info "Security configuration completed"
}

# Setup monitoring and notifications
setup_monitoring() {
    info "Setting up ArgoCD monitoring..."
    
    # Enable metrics
    kubectl patch configmap argocd-cmd-params-cm -n argocd --patch '{"data":{"application.instanceLabelKey":"argocd.argoproj.io/instance"}}'
    
    # Create monitoring ServiceMonitor if Prometheus is available
    cat <<EOF | kubectl apply -f - || warn "ServiceMonitor creation failed - Prometheus may not be installed"
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
  namespace: argocd
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-metrics
  endpoints:
  - port: metrics
EOF
    
    info "Monitoring setup completed"
}

# Validate configuration
validate_configuration() {
    info "Validating ArgoCD configuration..."
    
    # Check repositories
    local repos
    repos=$(kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=repository --no-headers 2>/dev/null | wc -l)
    info "Configured repositories: $repos"
    
    # Check projects
    local projects
    projects=$(kubectl get appprojects -n argocd --no-headers 2>/dev/null | wc -l)
    info "Configured projects: $projects"
    
    # Check ApplicationSets
    local appsets
    appsets=$(kubectl get applicationsets -n argocd --no-headers 2>/dev/null | wc -l)
    info "Configured ApplicationSets: $appsets"
    
    # Check applications
    local apps
    apps=$(kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l)
    info "Deployed applications: $apps"
    
    info "Configuration validation completed"
}

# Show ArgoCD access information
show_access_info() {
    info "ArgoCD Access Information"
    
    # Get admin password
    local admin_password=""
    if kubectl get secret argocd-initial-admin-secret -n argocd &>/dev/null; then
        admin_password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    fi
    
    echo ""
    echo "🔐 ArgoCD Web UI:"
    echo "  Port Forward: kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "  URL: https://localhost:8080"
    echo "  Username: admin"
    echo "  Password: $admin_password"
    
    echo ""
    echo "🔧 ArgoCD CLI Setup:"
    echo "  # Install ArgoCD CLI"
    echo "  curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64"
    echo "  sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd"
    echo ""
    echo "  # Login via CLI"
    echo "  argocd login localhost:8080 --username admin --password $admin_password --insecure"
    
    echo ""
    echo "📋 Next Steps:"
    echo "  1. Access ArgoCD Web UI"
    echo "  2. Verify repositories and projects"
    echo "  3. Deploy next wave: kubectl apply -f platform-services-v2/automation/gitops/applicationsets/wave1-shared-services.yaml"
    echo "  4. Monitor application sync status"
}

# Troubleshooting function
troubleshoot() {
    info "Running ArgoCD troubleshooting..."
    
    echo ""
    echo "=== ArgoCD Pod Status ==="
    kubectl get pods -n argocd
    
    echo ""
    echo "=== ArgoCD Services ==="
    kubectl get svc -n argocd
    
    echo ""
    echo "=== ArgoCD ConfigMaps ==="
    kubectl get configmaps -n argocd
    
    echo ""
    echo "=== ArgoCD Applications ==="
    kubectl get applications -n argocd
    
    echo ""
    echo "=== ArgoCD ApplicationSets ==="
    kubectl get applicationsets -n argocd
    
    echo ""
    echo "=== Recent ArgoCD Logs ==="
    kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server --tail=20
}

# Main configuration function
main() {
    log "Starting Wave 0 Configuration"
    
    verify_argocd
    configure_repositories
    configure_projects
    configure_security
    deploy_application_sets
    setup_monitoring
    validate_configuration
    show_access_info
    
    log "🎉 Wave 0 configuration completed successfully!"
}

# Handle script arguments
case "${1:-configure}" in
    "configure")
        main
        ;;
    "repositories")
        verify_argocd
        configure_repositories
        ;;
    "projects")
        verify_argocd
        configure_projects
        ;;
    "security")
        verify_argocd
        configure_security
        ;;
    "applicationsets")
        verify_argocd
        deploy_application_sets
        ;;
    "monitoring")
        verify_argocd
        setup_monitoring
        ;;
    "validate")
        verify_argocd
        validate_configuration
        ;;
    "access")
        show_access_info
        ;;
    "troubleshoot")
        troubleshoot
        ;;
    *)
        echo "Usage: $0 [configure|repositories|projects|security|applicationsets|monitoring|validate|access|troubleshoot]"
        echo ""
        echo "Commands:"
        echo "  configure      - Run full configuration (default)"
        echo "  repositories   - Configure ArgoCD repositories"
        echo "  projects       - Configure ArgoCD projects"
        echo "  security       - Configure RBAC and security"
        echo "  applicationsets- Deploy Wave ApplicationSets"
        echo "  monitoring     - Setup monitoring and metrics"
        echo "  validate       - Validate configuration"
        echo "  access         - Show access information"
        echo "  troubleshoot   - Run troubleshooting diagnostics"
        exit 1
        ;;
esac
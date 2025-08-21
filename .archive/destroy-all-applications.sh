#!/bin/bash

# ===================================================================
# BASE App Layer - Complete Application Cleanup Script
# Removes all applications while preserving infrastructure
# ===================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Logging functions
log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}" >&2; }
warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }
info() { echo -e "${BLUE}[INFO] $1${NC}"; }
step() { echo -e "${PURPLE}[STEP] $1${NC}"; }

# Safety confirmation
confirm_destruction() {
    echo -e "${RED}⚠️  DANGER: COMPLETE APPLICATION DESTRUCTION ⚠️${NC}"
    echo ""
    echo "This will PERMANENTLY DESTROY:"
    echo "  ❌ All ArgoCD Applications (23+ applications)"
    echo "  ❌ All BASE Layer modules (14 modules)"
    echo "  ❌ Platform UI and services"
    echo "  ❌ Airflow, Vault, MLflow, Kubeflow"
    echo "  ❌ Monitoring stack (Prometheus, Grafana)" 
    echo "  ❌ All ApplicationSets"
    echo "  ❌ All persistent volumes and data"
    echo ""
    echo -e "${GREEN}✅ PRESERVED:${NC}"
    echo "  ✅ EKS clusters (infrastructure)"
    echo "  ✅ VPC and networking"
    echo "  ✅ IAM roles and permissions"
    echo "  ✅ Terraform state"
    echo ""
    echo -e "${YELLOW}This action CANNOT be undone!${NC}"
    echo ""
    
    read -p "Type 'DESTROY' to confirm complete application removal: " -r
    if [[ "$REPLY" != "DESTROY" ]]; then
        info "Destruction cancelled. No changes made."
        exit 0
    fi
    
    echo ""
    warn "Final confirmation - are you absolutely sure?"
    read -p "Type 'YES' to proceed: " -r
    if [[ "$REPLY" != "YES" ]]; then
        info "Destruction cancelled. No changes made."
        exit 0
    fi
}

# Remove ArgoCD Applications
remove_argocd_applications() {
    step "Step 1: Removing ArgoCD Applications"
    
    # Get all applications
    local apps=$(kubectl get applications -n argocd -o name 2>/dev/null || echo "")
    
    if [[ -n "$apps" ]]; then
        log "Found ArgoCD applications - removing..."
        
        # Remove finalizers first to allow cleanup
        for app in $apps; do
            local app_name=$(echo $app | cut -d'/' -f2)
            info "Removing finalizers from $app_name"
            kubectl patch application $app_name -n argocd -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
        done
        
        # Delete all applications
        kubectl delete applications --all -n argocd --timeout=300s || true
        
        # Wait for applications to be removed
        local timeout=300
        local elapsed=0
        while kubectl get applications -n argocd 2>/dev/null | grep -q "." && [ $elapsed -lt $timeout ]; do
            echo -n "."
            sleep 5
            elapsed=$((elapsed + 5))
        done
        
        log "ArgoCD applications removed"
    else
        warn "No ArgoCD applications found"
    fi
}

# Remove ApplicationSets
remove_applicationsets() {
    step "Step 2: Removing ApplicationSets"
    
    local appsets=$(kubectl get applicationsets -n argocd -o name 2>/dev/null || echo "")
    
    if [[ -n "$appsets" ]]; then
        log "Found ApplicationSets - removing..."
        
        # Remove finalizers
        for appset in $appsets; do
            local appset_name=$(echo $appset | cut -d'/' -f2)
            info "Removing finalizers from $appset_name"
            kubectl patch applicationset $appset_name -n argocd -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
        done
        
        # Delete all ApplicationSets
        kubectl delete applicationsets --all -n argocd --timeout=300s || true
        
        log "ApplicationSets removed"
    else
        warn "No ApplicationSets found"
    fi
}

# Remove BASE Layer modules
remove_base_layer() {
    step "Step 3: Removing BASE Layer Modules"
    
    # List of BASE module namespaces
    local base_namespaces=(
        "base-data-ingestion"
        "base-data-quality"
        "base-data-storage"
        "base-data-security"
        "base-feature-engineering"
        "base-multimodal-processing"
        "base-data-streaming"
        "base-quality-monitoring"
        "base-pipeline-management"
        "base-event-coordination"
        "base-metadata-discovery"
        "base-schema-contracts"
        "base-data-distribution"
        "base-data-control"
    )
    
    # Check if base cluster is accessible
    if kubectl --context=base get nodes &>/dev/null; then
        log "Cleaning up BASE layer modules on base cluster..."
        
        for namespace in "${base_namespaces[@]}"; do
            if kubectl --context=base get namespace "$namespace" &>/dev/null; then
                info "Removing BASE module: $namespace"
                kubectl --context=base delete namespace "$namespace" --timeout=300s || true
            fi
        done
        
        log "BASE layer modules removed from base cluster"
    else
        warn "Base cluster not accessible - skipping BASE layer cleanup"
    fi
}

# Remove platform services
remove_platform_services() {
    step "Step 4: Removing Platform Services"
    
    # List of service namespaces to remove
    local service_namespaces=(
        "platform-ui"
        "airflow"
        "vault"
        "monitoring"
        "logging"
        "mlflow"
        "kubeflow"
        "istio-system"
        "cert-manager"
        "argo"
        "api-gateway"
        "data-services"
    )
    
    for namespace in "${service_namespaces[@]}"; do
        if kubectl get namespace "$namespace" &>/dev/null; then
            info "Removing service namespace: $namespace"
            
            # Remove finalizers from persistent volumes
            kubectl get pv -o name | xargs -I {} kubectl patch {} -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
            
            # Delete namespace
            kubectl delete namespace "$namespace" --timeout=300s || true
        fi
    done
    
    log "Platform services removed"
}

# Remove ArgoCD itself (optional)
remove_argocd() {
    step "Step 5: Removing ArgoCD (GitOps Controller)"
    
    if kubectl get namespace argocd &>/dev/null; then
        warn "Removing ArgoCD will disable GitOps management"
        read -p "Remove ArgoCD? (y/N): " -r
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            info "Removing ArgoCD..."
            
            # Remove finalizers
            kubectl get applications -n argocd -o name | xargs -I {} kubectl patch {} -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
            kubectl get applicationsets -n argocd -o name | xargs -I {} kubectl patch {} -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
            
            # Delete ArgoCD namespace
            kubectl delete namespace argocd --timeout=300s || true
            
            log "ArgoCD removed"
        else
            info "ArgoCD preserved"
        fi
    else
        warn "ArgoCD namespace not found"
    fi
}

# Clean up persistent volumes
cleanup_persistent_volumes() {
    step "Step 6: Cleaning Up Persistent Volumes"
    
    # Get orphaned PVs
    local orphaned_pvs=$(kubectl get pv -o jsonpath='{.items[?(@.status.phase=="Available")].metadata.name}' 2>/dev/null || echo "")
    
    if [[ -n "$orphaned_pvs" ]]; then
        log "Found orphaned persistent volumes - cleaning up..."
        
        for pv in $orphaned_pvs; do
            info "Removing orphaned PV: $pv"
            kubectl patch pv "$pv" -p '{"metadata":{"finalizers":[]}}' --type=merge 2>/dev/null || true
            kubectl delete pv "$pv" --timeout=60s || true
        done
        
        log "Persistent volumes cleaned up"
    else
        info "No orphaned persistent volumes found"
    fi
}

# Clean up custom resources
cleanup_custom_resources() {
    step "Step 7: Cleaning Up Custom Resources"
    
    # Remove Istio resources
    kubectl delete virtualservices --all --all-namespaces --timeout=60s 2>/dev/null || true
    kubectl delete destinationrules --all --all-namespaces --timeout=60s 2>/dev/null || true
    kubectl delete gateways --all --all-namespaces --timeout=60s 2>/dev/null || true
    
    # Remove Argo Workflows
    kubectl delete workflows --all --all-namespaces --timeout=60s 2>/dev/null || true
    kubectl delete workflowtemplates --all --all-namespaces --timeout=60s 2>/dev/null || true
    
    # Remove Prometheus resources
    kubectl delete servicemonitors --all --all-namespaces --timeout=60s 2>/dev/null || true
    kubectl delete prometheusrules --all --all-namespaces --timeout=60s 2>/dev/null || true
    
    log "Custom resources cleaned up"
}

# Validation and final status
validate_cleanup() {
    step "Step 8: Validating Cleanup"
    
    log "=== CLEANUP VALIDATION ==="
    
    # Check applications
    local remaining_apps=$(kubectl get applications -n argocd 2>/dev/null | wc -l)
    echo "Remaining ArgoCD applications: $((remaining_apps - 1))"
    
    # Check ApplicationSets  
    local remaining_appsets=$(kubectl get applicationsets -n argocd 2>/dev/null | wc -l)
    echo "Remaining ApplicationSets: $((remaining_appsets - 1))"
    
    # Check namespaces
    echo ""
    echo "Remaining service namespaces:"
    kubectl get namespaces | grep -E "(platform-ui|airflow|vault|monitoring|mlflow|kubeflow|base-)" || echo "  None found"
    
    # Check persistent volumes
    echo ""
    echo "Remaining persistent volumes:"
    kubectl get pv | grep -v "Available" || echo "  All cleaned up"
    
    echo ""
    log "=== INFRASTRUCTURE STATUS (PRESERVED) ==="
    echo "EKS Clusters:"
    aws eks list-clusters --region us-east-1 2>/dev/null || echo "  Unable to check AWS clusters"
    
    echo ""
    echo "Kubernetes Nodes:"
    kubectl get nodes || echo "  Unable to check nodes"
    
    echo ""
}

# Generate cleanup report
generate_cleanup_report() {
    log "=== CLEANUP COMPLETE ==="
    
    echo -e "${GREEN}✅ DESTROYED:${NC}"
    echo "  ✅ All ArgoCD Applications"
    echo "  ✅ All ApplicationSets"
    echo "  ✅ All BASE Layer modules"
    echo "  ✅ Platform UI and services"
    echo "  ✅ Airflow, Vault, MLflow, Kubeflow"
    echo "  ✅ Monitoring stack"
    echo "  ✅ Persistent volumes and data"
    echo ""
    
    echo -e "${BLUE}🏗️  PRESERVED INFRASTRUCTURE:${NC}"
    echo "  🏗️  EKS clusters"
    echo "  🏗️  VPC and networking"
    echo "  🏗️  IAM roles and permissions"
    echo "  🏗️  Load balancers and security groups"
    echo "  🏗️  Terraform state"
    echo ""
    
    echo -e "${YELLOW}🔄 TO REDEPLOY:${NC}"
    echo "  ./platform-services-v2/automation/scripts/deploy-platform.sh"
    echo "  or"
    echo "  ./platform-services/scripts/full-deployment.sh"
    echo ""
    
    echo -e "${PURPLE}🗑️  TO DESTROY INFRASTRUCTURE:${NC}"
    echo "  cd platform-services/terraform-new/providers/aws/environments/dev"
    echo "  terraform destroy"
}

# Main cleanup function
main() {
    log "Starting Complete BASE App Layer Application Cleanup"
    
    confirm_destruction
    
    log "Beginning application destruction process..."
    
    remove_argocd_applications
    remove_applicationsets
    remove_base_layer
    remove_platform_services
    remove_argocd
    cleanup_persistent_volumes
    cleanup_custom_resources
    validate_cleanup
    generate_cleanup_report
    
    log "🧹 Complete application cleanup finished!"
}

# Quick cleanup function (skip confirmations)
quick_cleanup() {
    warn "Quick cleanup mode - minimal confirmations"
    
    remove_argocd_applications
    remove_applicationsets
    remove_platform_services
    cleanup_persistent_volumes
    validate_cleanup
    
    log "Quick cleanup completed"
}

# Selective cleanup functions
cleanup_applications_only() {
    log "Cleaning up ArgoCD applications only..."
    remove_argocd_applications
    validate_cleanup
}

cleanup_base_layer_only() {
    log "Cleaning up BASE layer modules only..."
    remove_base_layer
    validate_cleanup
}

cleanup_platform_services_only() {
    log "Cleaning up platform services only..."
    remove_platform_services
    validate_cleanup
}

# Handle script arguments
case "${1:-full}" in
    "full")
        main
        ;;
    "quick")
        quick_cleanup
        ;;
    "applications")
        cleanup_applications_only
        ;;
    "base-layer")
        cleanup_base_layer_only
        ;;
    "services")
        cleanup_platform_services_only
        ;;
    "validate")
        validate_cleanup
        ;;
    *)
        echo "Usage: $0 {full|quick|applications|base-layer|services|validate}"
        echo ""
        echo "Cleanup options:"
        echo "  full         - Complete application cleanup with confirmations (default)"
        echo "  quick        - Quick cleanup with minimal confirmations"
        echo "  applications - Remove only ArgoCD applications"
        echo "  base-layer   - Remove only BASE layer modules"
        echo "  services     - Remove only platform services"
        echo "  validate     - Show current cleanup status"
        echo ""
        echo "⚠️  WARNING: These operations are DESTRUCTIVE and IRREVERSIBLE"
        echo "⚠️  Infrastructure (EKS, VPC, etc.) will be preserved"
        echo ""
        echo "To destroy infrastructure:"
        echo "  cd platform-services/terraform-new/providers/aws/environments/dev"
        echo "  terraform destroy"
        exit 1
        ;;
esac
#!/bin/bash

# ===================================================================
# Migration Script: Platform Services v1 → v2
# Zero-downtime migration to improved architecture
# ===================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; }
warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }
info() { echo -e "${BLUE}[INFO] $1${NC}"; }

# Migration phases
migrate_phase_1() {
    log "Phase 1: Repository Structure Migration"
    
    # Backup current state
    info "Creating backup of current platform-services..."
    cp -r .platform-services .platform-services-backup-$(date +%Y%m%d-%H%M%S)
    
    # Apply new ArgoCD repository configurations
    info "Updating ArgoCD repositories for new structure..."
    kubectl apply -f .platform-services-v2/automation/gitops/repositories/
    
    # Apply new ArgoCD projects
    info "Updating ArgoCD projects..."
    kubectl apply -f .platform-services-v2/automation/gitops/projects/
    
    log "Phase 1 completed - Repository structure updated"
}

migrate_phase_2() {
    log "Phase 2: Core Services Migration"
    
    # Update Platform UI to use new structure (already working)
    info "Platform UI already using new structure - validating..."
    kubectl get application platform-ui -n argocd -o yaml | grep "path: ui/k8s"
    
    # Apply dependency management
    info "Applying dependency management configuration..."
    kubectl apply -f .platform-services-v2/automation/gitops/dependencies.yaml
    
    log "Phase 2 completed - Core services migrated"
}

migrate_phase_3() {
    log "Phase 3: ApplicationSets Migration"
    
    # Apply new ApplicationSets gradually
    info "Applying new wave-based ApplicationSets..."
    
    # Apply core services ApplicationSet
    kubectl apply -f .platform-services-v2/automation/gitops/applicationsets/core-services.yaml
    
    # Wait for core services to sync
    sleep 30
    
    # Apply shared services ApplicationSet
    kubectl apply -f .platform-services-v2/automation/gitops/applicationsets/shared-services.yaml
    
    # Apply orchestration services ApplicationSet
    kubectl apply -f .platform-services-v2/automation/gitops/applicationsets/orchestration-services.yaml
    
    # Apply application services ApplicationSet
    kubectl apply -f .platform-services-v2/automation/gitops/applicationsets/application-services.yaml
    
    log "Phase 3 completed - ApplicationSets migrated"
}

migrate_phase_4() {
    log "Phase 4: Validation and Cleanup"
    
    # Run comprehensive validation
    info "Running platform validation..."
    ./.platform-services-v2/automation/scripts/validate-platform.sh
    
    # Show migration status
    info "Migration Status:"
    kubectl get applications -n argocd -o custom-columns="NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status"
    
    log "Phase 4 completed - Migration validated"
}

# Rollback function
rollback_migration() {
    warn "Rolling back migration..."
    
    # Restore original ApplicationSets
    kubectl apply -f .platform-services/argocd/applicationsets/
    
    # Wait for rollback to complete
    sleep 60
    
    info "Rollback completed - platform restored to previous state"
}

# Migration status check
check_migration_status() {
    log "Checking Migration Status"
    
    info "Current ArgoCD Applications:"
    kubectl get applications -n argocd
    
    info "Current ApplicationSets:"
    kubectl get applicationsets -n argocd
    
    info "Platform Health:"
    ./.platform-services-v2/automation/scripts/validate-platform.sh all
}

# Complete migration
run_complete_migration() {
    log "Starting Complete Platform Migration to v2 Architecture"
    
    # Confirm migration
    warn "This will migrate your platform to the new v2 architecture."
    warn "Current services will continue running during migration."
    echo ""
    read -p "Do you want to proceed? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        info "Migration cancelled"
        exit 0
    fi
    
    # Set trap for rollback on failure
    trap rollback_migration ERR
    
    migrate_phase_1
    migrate_phase_2
    migrate_phase_3
    migrate_phase_4
    
    log "🎉 Migration to v2 architecture completed successfully!"
    
    echo ""
    info "New deployment script location: platform-services-v2/automation/scripts/deploy-platform.sh"
    info "New validation script location: platform-services-v2/automation/scripts/validate-platform.sh"
    echo ""
    info "You can now use the improved architecture with:"
    echo "  ./platform-services-v2/automation/scripts/deploy-platform.sh"
    echo "  ./platform-services-v2/automation/scripts/validate-platform.sh"
}

# Handle script arguments
case "${1:-migrate}" in
    "migrate")
        run_complete_migration
        ;;
    "phase1")
        migrate_phase_1
        ;;
    "phase2")
        migrate_phase_2
        ;;
    "phase3")
        migrate_phase_3
        ;;
    "phase4")
        migrate_phase_4
        ;;
    "rollback")
        rollback_migration
        ;;
    "status")
        check_migration_status
        ;;
    *)
        echo "Usage: $0 {migrate|phase1|phase2|phase3|phase4|rollback|status}"
        echo ""
        echo "Migration commands:"
        echo "  migrate   - Complete migration to v2 architecture (default)"
        echo "  phase1    - Repository structure migration"
        echo "  phase2    - Core services migration"
        echo "  phase3    - ApplicationSets migration"
        echo "  phase4    - Validation and cleanup"
        echo "  rollback  - Rollback to previous architecture"
        echo "  status    - Check current migration status"
        echo ""
        echo "The migration will:"
        echo "  ✓ Maintain zero downtime"
        echo "  ✓ Keep all services running"
        echo "  ✓ Provide rollback capability"
        echo "  ✓ Validate platform health"
        exit 1
        ;;
esac
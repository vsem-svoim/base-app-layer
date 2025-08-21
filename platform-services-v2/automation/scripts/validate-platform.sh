#!/bin/bash

# ===================================================================
# BASE App Layer - Platform Validation Script
# Comprehensive health checks and deployment validation
# ===================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Status tracking
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0

# Helper functions
log() { echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; }
warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }
info() { echo -e "${BLUE}[INFO] $1${NC}"; }

check() {
    local description="$1"
    local command="$2"
    local warning_only="${3:-false}"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    printf "%-50s" "$description"
    
    if eval "$command" &>/dev/null; then
        echo -e "${GREEN}✓${NC}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        if [[ "$warning_only" == "true" ]]; then
            echo -e "${YELLOW}⚠${NC}"
            PASSED_CHECKS=$((PASSED_CHECKS + 1))
        else
            echo -e "${RED}✗${NC}"
            FAILED_CHECKS=$((FAILED_CHECKS + 1))
        fi
        return 1
    fi
}

# Infrastructure validation
validate_infrastructure() {
    log "=== Infrastructure Validation ==="
    
    check "Platform cluster connectivity" "kubectl --context=platform get nodes"
    check "Base cluster connectivity" "kubectl --context=base get nodes" true
    check "Platform cluster nodes ready" "kubectl --context=platform get nodes | grep -v NotReady"
    check "Base cluster nodes ready" "kubectl --context=base get nodes | grep -v NotReady" true
    
    # Storage classes
    check "Storage classes available" "kubectl --context=platform get storageclass"
    check "Default storage class set" "kubectl --context=platform get storageclass | grep default"
    
    echo ""
}

# Core services validation
validate_core_services() {
    log "=== Core Services Validation ==="
    
    # ArgoCD
    check "ArgoCD namespace exists" "kubectl --context=platform get namespace argocd"
    check "ArgoCD server running" "kubectl --context=platform get pods -n argocd -l app.kubernetes.io/name=argocd-server | grep Running"
    check "ArgoCD repo server running" "kubectl --context=platform get pods -n argocd -l app.kubernetes.io/name=argocd-repo-server | grep Running"
    check "ArgoCD applications accessible" "kubectl --context=platform get applications -n argocd"
    
    # Vault
    check "Vault namespace exists" "kubectl --context=platform get namespace vault" true
    check "Vault pods running" "kubectl --context=platform get pods -n vault -l app.kubernetes.io/name=vault | grep Running" true
    check "Vault unsealed status" "kubectl --context=platform exec -n vault vault-0 -- vault status" true
    
    # AWS Load Balancer Controller
    check "AWS LB Controller running" "kubectl --context=platform get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller | grep Running"
    
    # Cert Manager
    check "Cert Manager namespace exists" "kubectl --context=platform get namespace cert-manager" true
    check "Cert Manager running" "kubectl --context=platform get pods -n cert-manager -l app.kubernetes.io/name=cert-manager | grep Running" true
    
    echo ""
}

# Shared services validation
validate_shared_services() {
    log "=== Shared Services Validation ==="
    
    # Monitoring
    check "Monitoring namespace exists" "kubectl --context=platform get namespace monitoring" true
    check "Prometheus running" "kubectl --context=platform get pods -n monitoring -l app.kubernetes.io/name=prometheus | grep Running" true
    check "Grafana running" "kubectl --context=platform get pods -n monitoring -l app.kubernetes.io/name=grafana | grep Running" true
    
    # Istio
    check "Istio system namespace exists" "kubectl --context=platform get namespace istio-system" true
    check "Istiod running" "kubectl --context=platform get pods -n istio-system -l app=istiod | grep Running" true
    
    # Logging
    check "Logging namespace exists" "kubectl --context=platform get namespace logging" true
    check "Elasticsearch running" "kubectl --context=platform get pods -n logging -l app=elasticsearch | grep Running" true
    
    echo ""
}

# Orchestration services validation
validate_orchestration_services() {
    log "=== Orchestration Services Validation ==="
    
    # Airflow
    check "Airflow namespace exists" "kubectl --context=platform get namespace airflow"
    check "Airflow scheduler running" "kubectl --context=platform get pods -n airflow -l app=airflow-scheduler | grep Running"
    check "Airflow webserver running" "kubectl --context=platform get pods -n airflow -l app=airflow-webserver | grep Running"
    
    # MLflow
    check "MLflow namespace exists" "kubectl --context=platform get namespace mlflow" true
    check "MLflow server running" "kubectl --context=platform get pods -n mlflow -l app.kubernetes.io/name=mlflow | grep Running" true
    
    # Kubeflow
    check "Kubeflow namespace exists" "kubectl --context=platform get namespace kubeflow" true
    check "Kubeflow pipelines running" "kubectl --context=platform get pods -n kubeflow -l app.kubernetes.io/name=ml-pipeline | grep Running" true
    
    echo ""
}

# Application services validation
validate_application_services() {
    log "=== Application Services Validation ==="
    
    # Platform UI
    check "Platform UI namespace exists" "kubectl --context=platform get namespace platform-ui"
    check "Platform UI pods running" "kubectl --context=platform get pods -n platform-ui -l app=platform-ui-dashboard | grep Running"
    check "Platform UI service exists" "kubectl --context=platform get service -n platform-ui platform-ui-service"
    check "Platform UI ingress exists" "kubectl --context=platform get ingress -n platform-ui platform-ui-ingress"
    
    # API Gateway
    check "API Gateway namespace exists" "kubectl --context=platform get namespace api-gateway" true
    check "API Gateway running" "kubectl --context=platform get pods -n api-gateway -l app=api-gateway | grep Running" true
    
    echo ""
}

# BASE layer validation
validate_base_layer() {
    log "=== BASE Layer Validation ==="
    
    # Check if base cluster is accessible
    if kubectl --context=base get nodes &>/dev/null; then
        # Data ingestion module
        check "Data ingestion namespace exists" "kubectl --context=base get namespace base-data-ingestion"
        check "Data ingestion pods running" "kubectl --context=base get pods -n base-data-ingestion | grep Running" true
        
        # Other BASE modules
        local modules=(
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
        
        for module in "${modules[@]}"; do
            check "$module namespace exists" "kubectl --context=base get namespace $module" true
        done
    else
        warn "Base cluster not accessible - skipping BASE layer validation"
    fi
    
    echo ""
}

# Network and connectivity validation
validate_connectivity() {
    log "=== Network Connectivity Validation ==="
    
    # Ingress validation
    check "Platform UI ingress has address" "kubectl --context=platform get ingress -n platform-ui platform-ui-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' | grep -v '^$'"
    
    # Service mesh validation
    check "Istio proxy injection enabled" "kubectl --context=platform get namespace platform-ui -o jsonpath='{.metadata.labels.istio-injection}' | grep enabled" true
    
    # DNS resolution
    check "Cluster DNS working" "kubectl --context=platform run dns-test --image=busybox --rm -it --restart=Never -- nslookup kubernetes.default" true
    
    echo ""
}

# Security validation
validate_security() {
    log "=== Security Validation ==="
    
    # RBAC
    check "RBAC enabled" "kubectl --context=platform auth can-i '*' '*' --as=system:anonymous | grep -q no"
    
    # Network policies
    check "Network policies supported" "kubectl --context=platform get networkpolicy --all-namespaces" true
    
    # Pod security standards
    check "Pod security policies exist" "kubectl --context=platform get psp" true
    
    # Secrets management
    check "Vault secrets accessible" "kubectl --context=platform get secrets -n vault" true
    
    echo ""
}

# Performance validation
validate_performance() {
    log "=== Performance Validation ==="
    
    # Resource usage
    check "Cluster resource usage" "kubectl --context=platform top nodes" true
    check "Platform UI resource usage" "kubectl --context=platform top pods -n platform-ui" true
    check "ArgoCD resource usage" "kubectl --context=platform top pods -n argocd" true
    
    echo ""
}

# Service endpoints validation
validate_endpoints() {
    log "=== Service Endpoints Validation ==="
    
    # Get important service URLs
    info "Service Endpoints:"
    
    # ArgoCD
    if kubectl --context=platform get service argocd-server -n argocd &>/dev/null; then
        echo "  ArgoCD: kubectl port-forward svc/argocd-server -n argocd 8080:443"
    fi
    
    # Platform UI ALB
    local alb_hostname=""
    if alb_hostname=$(kubectl --context=platform get ingress platform-ui-ingress -n platform-ui -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null); then
        echo "  Platform UI: http://$alb_hostname"
    fi
    
    # Airflow
    if kubectl --context=platform get service airflow-webserver -n airflow &>/dev/null; then
        echo "  Airflow: kubectl port-forward svc/airflow-webserver -n airflow 8081:8080"
    fi
    
    # Grafana
    if kubectl --context=platform get service grafana -n monitoring &>/dev/null; then
        echo "  Grafana: kubectl port-forward svc/grafana -n monitoring 3000:80"
    fi
    
    echo ""
}

# Summary report
generate_summary() {
    log "=== Validation Summary ==="
    
    echo "Total checks: $TOTAL_CHECKS"
    echo "Passed: $PASSED_CHECKS"
    echo "Failed: $FAILED_CHECKS"
    
    local success_rate=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
    
    if [[ $FAILED_CHECKS -eq 0 ]]; then
        echo -e "${GREEN}✓ All critical checks passed! Platform is healthy.${NC}"
    elif [[ $success_rate -ge 80 ]]; then
        echo -e "${YELLOW}⚠ Platform is mostly healthy ($success_rate% success rate)${NC}"
        echo -e "${YELLOW}  Some optional services may not be running.${NC}"
    else
        echo -e "${RED}✗ Platform has issues ($success_rate% success rate)${NC}"
        echo -e "${RED}  Please review failed checks above.${NC}"
        exit 1
    fi
    
    echo ""
}

# Main validation function
main() {
    log "Starting BASE App Layer Platform Validation"
    echo ""
    
    validate_infrastructure
    validate_core_services
    validate_shared_services
    validate_orchestration_services
    validate_application_services
    validate_base_layer
    validate_connectivity
    validate_security
    validate_performance
    validate_endpoints
    generate_summary
    
    log "Platform validation completed successfully!"
}

# Handle script arguments
case "${1:-all}" in
    "all")
        main
        ;;
    "infrastructure")
        validate_infrastructure
        ;;
    "core")
        validate_core_services
        ;;
    "shared")
        validate_shared_services
        ;;
    "orchestration")
        validate_orchestration_services
        ;;
    "apps")
        validate_application_services
        ;;
    "base")
        validate_base_layer
        ;;
    "security")
        validate_security
        ;;
    *)
        echo "Usage: $0 {all|infrastructure|core|shared|orchestration|apps|base|security}"
        echo ""
        echo "Validation components:"
        echo "  all            - Complete platform validation (default)"
        echo "  infrastructure - Infrastructure and connectivity"
        echo "  core           - Core services (ArgoCD, Vault, etc)"
        echo "  shared         - Shared services (Monitoring, Logging)"
        echo "  orchestration  - Orchestration services (Airflow, MLflow)"
        echo "  apps           - Application services (Platform UI)"
        echo "  base           - BASE layer modules"
        echo "  security       - Security and RBAC validation"
        exit 1
        ;;
esac
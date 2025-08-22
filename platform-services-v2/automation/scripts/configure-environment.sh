#!/bin/bash
# ===================================================================
# Environment Configuration Script - Parameterize deployment values
# Makes the platform deployment environment-agnostic
# ===================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLATFORM_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

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

# Default configuration - can be overridden by environment variables
ENVIRONMENT="${ENVIRONMENT:-dev}"
REGION="${REGION:-us-east-1}"
PLATFORM_CLUSTER_NAME="${PLATFORM_CLUSTER_NAME:-platform-app-layer-${ENVIRONMENT}}"
BASE_CLUSTER_NAME="${BASE_CLUSTER_NAME:-base-app-layer-${ENVIRONMENT}}"
DOMAIN="${DOMAIN:-${ENVIRONMENT}.example.com}"
GITHUB_REPO="${GITHUB_REPO:-https://github.com/vsem-svoim/base-app-layer.git}"
BRANCH="${BRANCH:-main}"

# Function to get cluster server URL
get_cluster_server() {
    local cluster_name="$1"
    local context_name="arn:aws:eks:${REGION}:$(aws sts get-caller-identity --query Account --output text):cluster/${cluster_name}"
    
    if kubectl config get-contexts "$context_name" &>/dev/null; then
        kubectl config use-context "$context_name" &>/dev/null
        kubectl cluster-info | grep "control plane" | sed 's/.*https/https/' | sed 's/\x1b\[[0-9;]*m//g' | awk '{print $1}'
    else
        error "Cluster context not found: $context_name"
        return 1
    fi
}

# Function to update ApplicationSets with dynamic values
update_applicationset() {
    local file="$1"
    local platform_server="$2"
    local base_server="$3"
    
    info "Updating ApplicationSet: $file"
    
    # Create backup
    cp "$file" "${file}.backup"
    
    # Replace hardcoded values with parameters
    sed -i.tmp \
        -e "s|repoURL: https://github.com/vsem-svoim/base-app-layer.git|repoURL: ${GITHUB_REPO}|g" \
        -e "s|targetRevision: main|targetRevision: ${BRANCH}|g" \
        -e "s|server: https://[^/]*.amazonaws.com|server: ${platform_server}|g" \
        -e "/cluster: base/,/server:/ s|server: https://[^/]*.amazonaws.com|server: ${base_server}|g" \
        "$file" && rm -f "${file}.tmp"
}

# Function to update cluster-specific configurations
update_cluster_configs() {
    local platform_server="$1"
    local base_server="$2"
    
    info "Updating cluster configurations..."
    
    # Update environment config
    local env_config="${PLATFORM_ROOT}/environments/overlays/${ENVIRONMENT}/platform-config.yaml"
    if [[ -f "$env_config" ]]; then
        sed -i.tmp \
            -e "s|environment: \".*\"|environment: \"${ENVIRONMENT}\"|g" \
            -e "s|region: \".*\"|region: \"${REGION}\"|g" \
            -e "s|cluster-name: \".*\"|cluster-name: \"${BASE_CLUSTER_NAME}\"|g" \
            -e "s|domain: \".*\"|domain: \"${DOMAIN}\"|g" \
            "$env_config" && rm -f "${env_config}.tmp"
    fi
    
    # Update AWS Load Balancer Controller with cluster-specific tags
    find "${PLATFORM_ROOT}" -name "*aws-load-balancer-controller*.yaml" -exec \
        sed -i.tmp -e "s|cluster-name=.*|cluster-name=${PLATFORM_CLUSTER_NAME}|g" {} \; \
        -exec rm -f {}.tmp \;
}

# Function to create environment-specific ArgoCD cluster secrets
create_cluster_secrets() {
    local platform_server="$1"
    local base_server="$2"
    
    info "Creating ArgoCD cluster secrets..."
    
    # Create BASE cluster secret template
    cat > "${PLATFORM_ROOT}/automation/gitops/clusters/base-cluster-secret.yaml" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: base-cluster-secret
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
stringData:
  name: base-cluster
  server: ${base_server}
  config: |
    {
      "awsAuthConfig": {
        "clusterName": "${BASE_CLUSTER_NAME}",
        "roleARN": ""
      },
      "tlsClientConfig": {
        "insecure": false
      }
    }
EOF

    # Create platform cluster secret for self-reference
    cat > "${PLATFORM_ROOT}/automation/gitops/clusters/platform-cluster-secret.yaml" <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: platform-cluster-secret
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
stringData:
  name: in-cluster
  server: https://kubernetes.default.svc
  config: |
    {
      "tlsClientConfig": {
        "insecure": false,
        "caData": ""
      }
    }
EOF
}

# Function to update ArgoCD projects with environment-specific settings
update_projects() {
    local base_server="$1"
    
    info "Updating ArgoCD projects..."
    
    find "${PLATFORM_ROOT}/automation/gitops/projects" -name "*.yaml" -exec \
        sed -i.tmp \
            -e "s|server: https://[^/]*.amazonaws.com|server: ${base_server}|g" \
            -e "s|sourceRepos:.*|sourceRepos:\n  - '${GITHUB_REPO}'|g" \
            {} \; \
        -exec rm -f {}.tmp \;
}

# Main configuration function
main() {
    log "🔧 Configuring environment: $ENVIRONMENT"
    log "🌍 Region: $REGION"
    log "🏗️ Platform Cluster: $PLATFORM_CLUSTER_NAME"
    log "📊 BASE Cluster: $BASE_CLUSTER_NAME"
    log "🔗 Repository: $GITHUB_REPO"
    
    # Get cluster server URLs
    info "Getting cluster server URLs..."
    local platform_server
    local base_server
    
    platform_server=$(get_cluster_server "$PLATFORM_CLUSTER_NAME")
    base_server=$(get_cluster_server "$BASE_CLUSTER_NAME")
    
    log "Platform Server: $platform_server"
    log "BASE Server: $base_server"
    
    # Create clusters directory if it doesn't exist
    mkdir -p "${PLATFORM_ROOT}/automation/gitops/clusters"
    
    # Update all ApplicationSets
    info "Updating ApplicationSets..."
    find "${PLATFORM_ROOT}/automation/gitops/applicationsets" -name "*.yaml" | while read -r file; do
        update_applicationset "$file" "$platform_server" "$base_server"
    done
    
    # Update cluster-specific configurations
    update_cluster_configs "$platform_server" "$base_server"
    
    # Create cluster secrets
    create_cluster_secrets "$platform_server" "$base_server"
    
    # Update projects
    update_projects "$base_server"
    
    # Switch back to platform cluster
    kubectl config use-context "arn:aws:eks:${REGION}:$(aws sts get-caller-identity --query Account --output text):cluster/${PLATFORM_CLUSTER_NAME}"
    
    log "✅ Environment configuration completed!"
    log ""
    log "📋 Next steps:"
    log "  1. Review generated configurations in automation/gitops/"
    log "  2. Apply cluster secrets: kubectl apply -f automation/gitops/clusters/"
    log "  3. Deploy ApplicationSets: ./deploy-wave0-complete.sh"
    log "  4. Configure GitOps: ./configure-wave0.sh"
}

# Handle script arguments for different environments
case "${1:-configure}" in
    "configure")
        main
        ;;
    "dev"|"staging"|"prod")
        export ENVIRONMENT="$1"
        export PLATFORM_CLUSTER_NAME="platform-app-layer-$1"
        export BASE_CLUSTER_NAME="base-app-layer-$1"
        export DOMAIN="$1.example.com"
        main
        ;;
    "restore")
        info "Restoring from backups..."
        find "${PLATFORM_ROOT}/automation/gitops" -name "*.backup" | while read -r backup; do
            original="${backup%.backup}"
            mv "$backup" "$original"
            log "Restored: $original"
        done
        ;;
    *)
        echo "Usage: $0 [configure|dev|staging|prod|restore]"
        echo ""
        echo "Environment Variables (optional):"
        echo "  ENVIRONMENT           - Target environment (default: dev)"
        echo "  REGION               - AWS region (default: us-east-1)"
        echo "  PLATFORM_CLUSTER_NAME - Platform cluster name"
        echo "  BASE_CLUSTER_NAME    - BASE cluster name"
        echo "  DOMAIN               - Base domain"
        echo "  GITHUB_REPO          - Git repository URL"
        echo "  BRANCH               - Git branch (default: main)"
        echo ""
        echo "Examples:"
        echo "  # Configure for dev environment"
        echo "  ./configure-environment.sh dev"
        echo ""
        echo "  # Configure for production with custom settings"
        echo "  REGION=us-west-2 DOMAIN=prod.mycompany.com ./configure-environment.sh prod"
        echo ""
        echo "  # Restore original configurations"
        echo "  ./configure-environment.sh restore"
        exit 1
        ;;
esac
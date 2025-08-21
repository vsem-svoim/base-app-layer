#!/bin/bash

# STAGE 2: Provider Configuration - Main Orchestration Script
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_DIR="$(pwd)"

CLOUD_PROVIDER=""
REGION=""
PROVIDER_SCRIPT_PATH=""
PLATFORM_SERVICES_DIR=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

log_info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
}

show_help() {
    cat << EOF
STAGE 2: Provider Configuration (Crossplane + Terraform)
Usage: $0 --provider PROVIDER --region REGION

Options:
  -p, --provider PROVIDER   Cloud provider (aws|gcp|azure|onprem)
  -r, --region REGION       Region
  -h, --help               Show help

Architecture:
  • Terraform: VPC, EKS/GKE/AKS clusters, IAM policies
  • Crossplane: Application infrastructure (RDS, S3, etc.)
  • ArgoCD: GitOps for both infrastructure and applications
  • Helm: Provider-specific values for platform services

Examples:
  $0 --provider aws --region us-east-1
  $0 --provider gcp --region us-central1
  $0 --provider azure --region eastus
  $0 --provider onprem --region datacenter-1

Provider Scripts:
  This script will call the appropriate provider-specific script:
  • stage2-aws-provider.sh
  • stage2-gcp-provider.sh
  • stage2-azure-provider.sh
  • stage2-onprem-provider.sh
EOF
}

# Load platform configuration created by Stage 1
load_platform_config() {
    if [[ -f ".stage1-output" ]]; then
        log "Loading Stage 1 configuration..."
        source .stage1-output
        log_info "BASE Layer Repository: $BASE_LAYER_REPO_URL"
        log_info "BASE Layer Components: $BASE_LAYER_COMPONENTS"
        log_info "Project: $PROJECT_ROOT"
        log_info "GitHub Organization: $GITHUB_ORG"
        log_info "Cluster: $CLUSTER_NAME"
        log_info "Environment: $ENVIRONMENT"
    else
        log_error "File .stage1-output not found. Run Stage 1 first."
        exit 1
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--provider)
                CLOUD_PROVIDER="$2"
                shift 2
                ;;
            -r|--region)
                REGION="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown parameter: $1"
                show_help
                exit 1
                ;;
        esac
    done

    if [[ -z "$CLOUD_PROVIDER" ]] || [[ -z "$REGION" ]]; then
        log_error "Provider and region are required"
        show_help
        exit 1
    fi

    case $CLOUD_PROVIDER in
        aws|gcp|azure|onprem) ;;
        *)
            log_error "Unsupported provider: $CLOUD_PROVIDER"
            exit 1
            ;;
    esac
}

validate_environment() {
    log "Validating environment..."

    # Check if we're already in .platform-services directory
    local required_dirs=("terraform" "crossplane" "helm-charts" "argocd" "kustomize")
    local all_dirs_exist=true

    # First, check if we're already in the .platform-services directory
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            all_dirs_exist=false
            break
        fi
    done

    if [[ "$all_dirs_exist" == "true" ]]; then
        log "✅ Already in platform-services directory"
        PLATFORM_SERVICES_DIR="$(pwd)"
    else
        # Check if we're in the project root (.platform-services subdirectory exists)
        if [[ -d "platform-services" ]]; then
            log "✅ Found platform-services directory, changing to it"
            cd .platform-services
            PLATFORM_SERVICES_DIR="$(pwd)"

            # Verify Stage 1 structure exists
            for dir in "${required_dirs[@]}"; do
                if [[ ! -d "$dir" ]]; then
                    log_error "Required directory '$dir' not found in platform-services/. Stage 1 may not have completed successfully."
                    exit 1
                fi
            done
        else
            log_error "Neither in platform-services directory nor can find platform-services subdirectory."
            log_error "Please run this script either from:"
            log_error "  1. The project root (where platform-services/ exists), or"
            log_error "  2. Inside the platform-services/ directory"
            log_error ""
            log_error "Current directory: $(pwd)"
            log_error "Directory contents: $(ls -la)"
            exit 1
        fi
    fi

    log "✅ Environment validation passed"
    log_info "Working directory: $PLATFORM_SERVICES_DIR"
}

check_provider_script() {
    local provider_script="stage2-${CLOUD_PROVIDER}-provider.sh"
    local script_path=""

    # Check multiple possible locations for the provider script
    local possible_paths=(
        "${SCRIPT_DIR}/${provider_script}"           # Same directory as main script
        "../${provider_script}"                      # Parent directory (if we're in .platform-services)
        "./${provider_script}"                       # Current directory
        "${SCRIPT_DIR}/../${provider_script}"        # Parent of script directory
    )

    for path in "${possible_paths[@]}"; do
        if [[ -f "$path" ]]; then
            script_path="$path"
            break
        fi
    done

    if [[ -z "$script_path" ]]; then
        log_error "Provider script not found: $provider_script"
        log_error "Searched in the following locations:"
        for path in "${possible_paths[@]}"; do
            log_error "  - $path"
        done
        log_error ""
        log_error "Available provider scripts should be:"
        log_error "  - stage2-aws-provider.sh"
        log_error "  - stage2-gcp-provider.sh"
        log_error "  - stage2-azure-provider.sh"
        log_error "  - stage2-onprem-provider.sh"
        exit 1
    fi

    if [[ ! -x "$script_path" ]]; then
        log "Making provider script executable..."
        chmod +x "$script_path"
    fi

    # Store the found script path for later use
    PROVIDER_SCRIPT_PATH="$script_path"
    log "✅ Provider script found: $script_path"
    return 0
}

call_provider_script() {
    local provider_script="stage2-${CLOUD_PROVIDER}-provider.sh"

    log "========================================="
    log "Calling $CLOUD_PROVIDER provider script..."
    log "========================================="

    # Export variables for the provider script
    export CLOUD_PROVIDER
    export REGION
    export PROJECT_ROOT
    export GITHUB_ORG
    export CLUSTER_NAME
    export ENVIRONMENT
    export BASE_LAYER_REPO_URL
    export BASE_LAYER_COMPONENTS

    # Call the provider-specific script using the found path
    if "$PROVIDER_SCRIPT_PATH" --region "$REGION"; then
        log "✅ $CLOUD_PROVIDER provider configuration completed successfully"
    else
        log_error "❌ $CLOUD_PROVIDER provider configuration failed"
        exit 1
    fi
}

save_stage2_output() {
    log "Saving Stage 2 configuration..."

    # Determine where to save the configuration file
    local config_file=""
    if [[ -f ".stage1-output" ]]; then
        config_file=".stage1-output"
    elif [[ -f "../.stage1-output" ]]; then
        config_file="../.stage1-output"
    else
        log_warning "Could not find .stage1-output file, creating new configuration file"
        config_file=".stage2-output"
    fi

    # Append to existing stage1 output to create combined config
    cat >> "$config_file" << EOF

# Stage 2 Output - Provider Configuration
CLOUD_PROVIDER="$CLOUD_PROVIDER"
REGION="$REGION"
STAGE2_COMPLETED_AT="$(date '+%Y-%m-%d %H:%M:%S')"
PROVIDER_CONFIG_PATH="$PLATFORM_SERVICES_DIR"
EOF

    log "✅ Stage 2 configuration saved to $config_file"
}

main() {
    log "========================================="
    log "STAGE 2: Provider Configuration"
    log "Hybrid Architecture: Terraform + Crossplane"
    log "========================================="

    # Load configuration and parse arguments
    load_platform_config
    parse_args "$@"

    log_info "Provider: $CLOUD_PROVIDER"
    log_info "Region: $REGION"
    log_info "Project: $PROJECT_ROOT"
    log_info "Environment: $ENVIRONMENT"

    # Validate environment and check for provider script
    validate_environment
    check_provider_script

    # Call the provider-specific script
    call_provider_script

    # Save configuration
    save_stage2_output

    log ""
    log "========================================="
    log "STAGE 2 COMPLETED SUCCESSFULLY"
    log "========================================="
    log ""
    log "CONFIGURATION CREATED:"
    log "====================="
    log "✅ Terraform: Core infrastructure modules"
    log "✅ Crossplane: Application infrastructure"
    log "✅ ArgoCD: GitOps applications"
    log "✅ Helm: Provider-specific values"
    log "✅ Kustomize: Provider-specific overlays"
    log ""
    log "NEXT STEPS:"
    log "==========="
    log "1. Review generated configurations in platform-services/"
    log "2. Run Stage 3: ./stage3-deploy-resources.sh $ENVIRONMENT $CLOUD_PROVIDER $REGION"
    log ""
    log "ARCHITECTURE:"
    log "============="
    log "• Terraform: Core infrastructure (VPC, K8s cluster, IAM)"
    log "• Crossplane: Application resources (databases, storage)"
    log "• ArgoCD: GitOps deployment and management"
    log "• Helm: Platform services configuration"
    log ""
    log "Provider-specific configuration completed for $CLOUD_PROVIDER!"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
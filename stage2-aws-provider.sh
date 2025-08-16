#!/bin/bash

# STAGE 2: AWS Provider Configuration
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_DIR="$(pwd)"

# Get parameters from environment (set by main script) or command line
REGION="${REGION:-}"
PROJECT_ROOT="${PROJECT_ROOT:-$(basename "$SCRIPT_DIR")}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
CLUSTER_NAME="${CLUSTER_NAME:-${PROJECT_ROOT}-${ENVIRONMENT}-cluster}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log() {
    echo -e "${GREEN}[AWS $(date +'%H:%M:%S')]${NC} $1"
}

log_error() {
    echo -e "${RED}[AWS ERROR]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[AWS WARNING]${NC} $1"
}

log_info() {
    echo -e "${BLUE}[AWS INFO]${NC} $1"
}

show_help() {
    cat << EOF
STAGE 2: AWS Provider Configuration

Usage: $0 --region REGION

Options:
  -r, --region REGION       AWS region (e.g., us-east-1)
  -h, --help               Show help

This script configures AWS-specific infrastructure:
  • EKS cluster with Fargate profiles
  • VPC with public/private subnets
  • IAM roles and policies
  • Crossplane AWS providers
  • AWS-specific Helm values
  • AWS-optimized ArgoCD applications

Prerequisites:
  • AWS CLI installed and configured
  • Valid AWS credentials/profile
  • kubectl installed
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
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

    if [[ -z "$REGION" ]]; then
        log_error "AWS region is required"
        show_help
        exit 1
    fi
}

# Check if profile might be SSO and offer login
check_sso_profile() {
    local profile_name="$1"

    # Check if this looks like an SSO profile
    if [[ "$profile_name" == *"AdministratorAccess"* ]] || [[ "$profile_name" == *"PowerUser"* ]] || [[ "$profile_name" == *"ReadOnly"* ]]; then
        log_info "Profile name suggests this might be an AWS SSO profile"

        # Check if SSO is configured for this profile
        if aws configure get sso_start_url --profile "$profile_name" &> /dev/null; then
            log "This appears to be an AWS SSO profile"
            log "Checking SSO login status..."

            # Try to get cached SSO credentials
            if ! aws sts get-caller-identity --profile "$profile_name" &> /dev/null; then
                log_warning "SSO credentials may have expired"
                echo ""
                read -p "Would you like to log in to AWS SSO now? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    log "Logging in to AWS SSO..."
                    if aws sso login --profile "$profile_name"; then
                        log "✅ SSO login successful"
                        return 0
                    else
                        log_error "SSO login failed"
                        return 1
                    fi
                else
                    log_warning "Skipping SSO login. You may need to run:"
                    log_warning "aws sso login --profile $profile_name"
                    return 1
                fi
            fi
        fi
    fi

# AWS profile selection and validation
select_aws_profile() {
    log "AWS profile and credentials validation..."

    # Check if AWS CLI is available
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI not installed. Please install AWS CLI to continue."
        exit 1
    fi

    # Get available AWS profiles
    local available_profiles
    if available_profiles=$(aws configure list-profiles 2>/dev/null); then
        if [[ -z "$available_profiles" ]]; then
            log_error "No AWS profiles configured. Run 'aws configure' to set up a profile."
            exit 1
        fi

        # Convert to array
        local profiles_array=()
        while IFS= read -r profile; do
            profiles_array+=("$profile")
        done <<< "$available_profiles"

        # If only one profile, use it
        if [[ ${#profiles_array[@]} -eq 1 ]]; then
            export AWS_PROFILE="${profiles_array[0]}"
            log "Using single AWS profile: $AWS_PROFILE"
        else
            # Multiple profiles - let user choose
            log "Available AWS profiles:"
            for i in "${!profiles_array[@]}"; do
                echo "  $((i+1)). ${profiles_array[$i]}"
            done

            while true; do
                read -rp "Select profile number (1-${#profiles_array[@]}): " choice
                if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#profiles_array[@]} ]]; then
                    export AWS_PROFILE="${profiles_array[$((choice-1))]}"
                    log "Selected AWS profile: $AWS_PROFILE"
                    break
                else
                    log_warning "Invalid choice. Enter a number from 1 to ${#profiles_array[@]}"
                fi
            done
        fi
    else
        log_error "Failed to get AWS profiles list. Check AWS CLI configuration."
        exit 1
    fi

    # Check if this might be an SSO profile and handle login
    check_sso_profile "$AWS_PROFILE" || {
        log_warning "SSO check failed, continuing with standard credential validation..."
    }

    # Test AWS access with detailed debugging
    log "Validating AWS access..."
    log_info "Testing with profile: $AWS_PROFILE"
    log_info "AWS CLI version: $(aws --version 2>/dev/null || echo 'AWS CLI not found')"

    # Check if the profile has credentials configured
    log "Checking profile configuration..."
    if aws configure list --profile "$AWS_PROFILE" &> /dev/null; then
        log "✅ Profile configuration found"
        log "Profile details:"
        aws configure list --profile "$AWS_PROFILE" | while read line; do
            log "   $line"
        done
    else
        log_error "Profile $AWS_PROFILE not properly configured"
        log_error "Run: aws configure --profile $AWS_PROFILE"
        exit 1
    fi

    # Test actual AWS API access
    log "Testing AWS API access..."
    local sts_output
    if sts_output=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --region "$REGION" 2>&1); then
        local aws_account=$(echo "$sts_output" | jq -r '.Account' 2>/dev/null || echo "$sts_output" | grep -oE '"Account":\s*"[0-9]+"' | cut -d'"' -f4)
        local aws_user=$(echo "$sts_output" | jq -r '.Arn' 2>/dev/null || echo "$sts_output" | grep -oE '"Arn":\s*"[^"]+"' | cut -d'"' -f4)
        local aws_user_id=$(echo "$sts_output" | jq -r '.UserId' 2>/dev/null || echo "$sts_output" | grep -oE '"UserId":\s*"[^"]+"' | cut -d'"' -f4)

        log "✅ AWS access confirmed:"
        log "   Account: $aws_account"
        log "   User: $aws_user"
        log "   User ID: $aws_user_id"
        log "   Profile: $AWS_PROFILE"
        log "   Region: $REGION"

        # Save AWS profile to config file
        cat > .aws-config << EOF
export AWS_PROFILE="$AWS_PROFILE"
export AWS_DEFAULT_REGION="$REGION"
export AWS_ACCOUNT_ID="$aws_account"
export AWS_USER_ARN="$aws_user"
EOF
        log "AWS configuration saved to .aws-config"

        # Export for immediate use
        export AWS_PROFILE
        export AWS_DEFAULT_REGION="$REGION"

    else
        log_error "Failed to access AWS with profile $AWS_PROFILE"
        log_error "AWS CLI output:"
        echo "$sts_output" | while read line; do
            log_error "   $line"
        done
        log_error ""
        log_error "Troubleshooting steps:"
        log_error "1. Check if credentials are valid:"
        log_error "   aws configure list --profile $AWS_PROFILE"
        log_error ""
        log_error "2. Test basic access:"
        log_error "   aws sts get-caller-identity --profile $AWS_PROFILE"
        log_error ""
        log_error "3. Check if credentials expired (if using temporary credentials)"
        log_error ""
        log_error "4. Reconfigure the profile:"
        log_error "   aws configure --profile $AWS_PROFILE"
        log_error ""
        log_error "5. If using SSO, ensure you're logged in:"
        log_error "   aws sso login --profile $AWS_PROFILE"
        exit 1
    fi
}

    # Test AWS access with detailed debugging
    log "Validating AWS access..."
    log_info "Testing with profile: $AWS_PROFILE"
    log_info "AWS CLI version: $(aws --version 2>/dev/null || echo 'AWS CLI not found')"

    # Check if the profile has credentials configured
    log "Checking profile configuration..."
    if aws configure list --profile "$AWS_PROFILE" &> /dev/null; then
        log "✅ Profile configuration found"
        log "Profile details:"
        aws configure list --profile "$AWS_PROFILE" | while read line; do
            log "   $line"
        done
    else
        log_error "Profile $AWS_PROFILE not properly configured"
        log_error "Run: aws configure --profile $AWS_PROFILE"
        exit 1
    fi

    # Test actual AWS API access
    log "Testing AWS API access..."
    local sts_output
    if sts_output=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --region "$REGION" 2>&1); then
        local aws_account=$(echo "$sts_output" | jq -r '.Account' 2>/dev/null || echo "$sts_output" | grep -oE '"Account":\s*"[0-9]+"' | cut -d'"' -f4)
        local aws_user=$(echo "$sts_output" | jq -r '.Arn' 2>/dev/null || echo "$sts_output" | grep -oE '"Arn":\s*"[^"]+"' | cut -d'"' -f4)
        local aws_user_id=$(echo "$sts_output" | jq -r '.UserId' 2>/dev/null || echo "$sts_output" | grep -oE '"UserId":\s*"[^"]+"' | cut -d'"' -f4)

        log "✅ AWS access confirmed:"
        log "   Account: $aws_account"
        log "   User: $aws_user"
        log "   User ID: $aws_user_id"
        log "   Profile: $AWS_PROFILE"
        log "   Region: $REGION"

        # Save AWS profile to config file
        cat > .aws-config << EOF
export AWS_PROFILE="$AWS_PROFILE"
export AWS_DEFAULT_REGION="$REGION"
export AWS_ACCOUNT_ID="$aws_account"
export AWS_USER_ARN="$aws_user"
EOF
        log "AWS configuration saved to .aws-config"

        # Export for immediate use
        export AWS_PROFILE
        export AWS_DEFAULT_REGION="$REGION"

    else
        log_error "Failed to access AWS with profile $AWS_PROFILE"
        log_error "AWS CLI output:"
        echo "$sts_output" | while read line; do
            log_error "   $line"
        done
        log_error ""
        log_error "Troubleshooting steps:"
        log_error "1. Check if credentials are valid:"
        log_error "   aws configure list --profile $AWS_PROFILE"
        log_error ""
        log_error "2. Test basic access:"
        log_error "   aws sts get-caller-identity --profile $AWS_PROFILE"
        log_error ""
        log_error "3. Check if credentials expired (if using temporary credentials)"
        log_error ""
        log_error "4. Reconfigure the profile:"
        log_error "   aws configure --profile $AWS_PROFILE"
        log_error ""
        log_error "5. If using SSO, ensure you're logged in:"
        log_error "   aws sso login --profile $AWS_PROFILE"
        exit 1
    fi
}

# Create AWS Terraform modules for configurable multi-cluster architecture
create_aws_terraform_modules() {
    log "Creating configurable AWS Terraform modules for multi-cluster architecture..."

    # Create comprehensive variables.tf with all configuration options
    cat > terraform/modules/kubernetes/variables.tf << 'EOF'
# Project Configuration
variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones_count" {
  description = "Number of availability zones to use"
  type        = number
  default     = 3
  validation {
    condition     = var.availability_zones_count >= 2 && var.availability_zones_count <= 6
    error_message = "Availability zones count must be between 2 and 6."
  }
}

variable "private_subnets_count" {
  description = "Number of private subnets per AZ"
  type        = number
  default     = 1
}

variable "public_subnets_count" {
  description = "Number of public subnets per AZ"
  type        = number
  default     = 1
}

variable "nat_gateway_count" {
  description = "Number of NAT gateways (0 = no NAT, 1 = single NAT, 2+ = multiple NAT)"
  type        = number
  default     = 1
  validation {
    condition     = var.nat_gateway_count >= 0
    error_message = "NAT gateway count must be 0 or greater."
  }
}

variable "enable_nat_gateway" {
  description = "Enable NAT gateway"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT gateway for all private subnets"
  type        = bool
  default     = false
}

variable "one_nat_gateway_per_az" {
  description = "Use one NAT gateway per availability zone"
  type        = bool
  default     = true
}

# BASE Layer Cluster Configuration
variable "base_cluster_enabled" {
  description = "Enable BASE layer cluster"
  type        = bool
  default     = true
}

variable "base_cluster_config" {
  description = "Configuration for BASE layer cluster"
  type = object({
    name               = string
    version            = string
    enable_fargate     = bool
    enable_managed_nodes = bool
    fargate_profiles   = map(object({
      namespace_selectors = list(string)
      label_selectors    = map(string)
    }))
    managed_node_groups = map(object({
      instance_types = list(string)
      capacity_type  = string
      min_size      = number
      max_size      = number
      desired_size  = number
      disk_size     = number
      disk_type     = string
      ami_type      = string
      labels        = map(string)
      taints = map(object({
        key    = string
        value  = string
        effect = string
      }))
    }))
  })
  default = {
    name               = "base-layer"
    version            = "1.33"
    enable_fargate     = true
    enable_managed_nodes = true
    fargate_profiles = {
      base_components = {
        namespace_selectors = ["base-*"]
        label_selectors    = {}
      }
    }
    managed_node_groups = {
      base_layer_nodes = {
        instance_types = ["t3.medium", "t3.large"]
        capacity_type  = "ON_DEMAND"
        min_size      = 1
        max_size      = 10
        desired_size  = 3
        disk_size     = 50
        disk_type     = "gp3"
        ami_type      = "AL2_x86_64"
        labels = {
          NodeGroup   = "base-layer"
          Environment = "dev"
        }
        taints = {
          base_layer = {
            key    = "base-layer"
            value  = "true"
            effect = "NO_SCHEDULE"
          }
        }
      }
    }
  }
}

# Platform Services Cluster Configuration
variable "platform_cluster_enabled" {
  description = "Enable platform services cluster"
  type        = bool
  default     = true
}

variable "platform_cluster_config" {
  description = "Configuration for platform services cluster"
  type = object({
    name               = string
    version            = string
    enable_fargate     = bool
    enable_managed_nodes = bool
    fargate_profiles   = map(object({
      namespace_selectors = list(string)
      label_selectors    = map(string)
    }))
    managed_node_groups = map(object({
      instance_types = list(string)
      capacity_type  = string
      min_size      = number
      max_size      = number
      desired_size  = number
      disk_size     = number
      disk_type     = string
      ami_type      = string
      labels        = map(string)
      taints = map(object({
        key    = string
        value  = string
        effect = string
      }))
    }))
  })
  default = {
    name               = "platform-services"
    version            = "1.33"
    enable_fargate     = true
    enable_managed_nodes = true
    fargate_profiles = {
      platform_default = {
        namespace_selectors = ["default", "kube-system"]
        label_selectors    = {}
      }
      platform_services = {
        namespace_selectors = ["argocd", "crossplane-system", "monitoring"]
        label_selectors    = {}
      }
      ml_platform = {
        namespace_selectors = ["ml-*"]
        label_selectors    = {}
      }
    }
    managed_node_groups = {
      platform_nodes = {
        instance_types = ["t3.large", "t3.xlarge"]
        capacity_type  = "ON_DEMAND"
        min_size      = 1
        max_size      = 10
        desired_size  = 3
        disk_size     = 100
        disk_type     = "gp3"
        ami_type      = "AL2_x86_64"
        labels = {
          NodeGroup   = "platform-services"
          Environment = "dev"
        }
        taints = {}
      }
      ml_nodes = {
        instance_types = ["m5.large", "m5.xlarge"]
        capacity_type  = "SPOT"
        min_size      = 0
        max_size      = 20
        desired_size  = 2
        disk_size     = 100
        disk_type     = "gp3"
        ami_type      = "AL2_x86_64"
        labels = {
          NodeGroup   = "ml-workloads"
          Environment = "dev"
        }
        taints = {
          ml_workload = {
            key    = "ml-workload"
            value  = "true"
            effect = "NO_SCHEDULE"
          }
        }
      }
    }
  }
}

# EKS Add-ons Configuration
variable "cluster_addons" {
  description = "EKS cluster add-ons configuration"
  type = map(object({
    most_recent    = bool
    addon_version  = string
    configuration_values = string
  }))
  default = {
    coredns = {
      most_recent           = true
      addon_version        = ""
      configuration_values = ""
    }
    kube-proxy = {
      most_recent           = true
      addon_version        = ""
      configuration_values = ""
    }
    vpc-cni = {
      most_recent    = true
      addon_version = ""
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
    aws-ebs-csi-driver = {
      most_recent           = true
      addon_version        = ""
      configuration_values = ""
    }
  }
}

# IAM Configuration
variable "enable_irsa" {
  description = "Enable IAM Roles for Service Accounts"
  type        = bool
  default     = true
}

variable "irsa_roles" {
  description = "IRSA roles configuration"
  type = map(object({
    policy_arns = list(string)
    namespaces  = list(string)
    service_accounts = list(string)
  }))
  default = {
    crossplane = {
      policy_arns      = ["arn:aws:iam::aws:policy/AdministratorAccess"]
      namespaces       = ["crossplane-system"]
      service_accounts = ["crossplane"]
    }
    argocd = {
      policy_arns      = ["arn:aws:iam::aws:policy/AdministratorAccess"]
      namespaces       = ["argocd"]
      service_accounts = ["argocd-server", "argocd-application-controller"]
    }
  }
}

# Tags
variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
EOF

    # Create flexible main.tf
    cat > terraform/modules/kubernetes/main.tf << 'EOF'
# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.availability_zones_count)

  # Calculate subnet CIDRs dynamically
  private_subnet_cidrs = [
    for i in range(var.availability_zones_count * var.private_subnets_count) :
    cidrsubnet(var.vpc_cidr, 8, i)
  ]

  public_subnet_cidrs = [
    for i in range(var.availability_zones_count * var.public_subnets_count) :
    cidrsubnet(var.vpc_cidr, 8, i + (var.availability_zones_count * var.private_subnets_count))
  ]

  # Cluster names
  base_cluster_name     = var.base_cluster_enabled ? "${var.project_name}-${var.base_cluster_config.name}-${var.environment}" : ""
  platform_cluster_name = var.platform_cluster_enabled ? "${var.project_name}-${var.platform_cluster_config.name}-${var.environment}" : ""
}

# Shared VPC for both clusters
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = local.private_subnet_cidrs
  public_subnets  = local.public_subnet_cidrs

  # NAT Gateway configuration
  enable_nat_gateway     = var.enable_nat_gateway
  single_nat_gateway     = var.single_nat_gateway
  one_nat_gateway_per_az = var.one_nat_gateway_per_az

  enable_vpn_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tags for cluster discovery
  tags = merge(var.tags, {
    "kubernetes.io/cluster/${local.base_cluster_name}"     = var.base_cluster_enabled ? "shared" : ""
    "kubernetes.io/cluster/${local.platform_cluster_name}" = var.platform_cluster_enabled ? "shared" : ""
  })

  public_subnet_tags = merge(
    var.base_cluster_enabled ? {
      "kubernetes.io/cluster/${local.base_cluster_name}" = "shared"
    } : {},
    var.platform_cluster_enabled ? {
      "kubernetes.io/cluster/${local.platform_cluster_name}" = "shared"
    } : {},
    {
      "kubernetes.io/role/elb" = "1"
    }
  )

  private_subnet_tags = merge(
    var.base_cluster_enabled ? {
      "kubernetes.io/cluster/${local.base_cluster_name}" = "shared"
    } : {},
    var.platform_cluster_enabled ? {
      "kubernetes.io/cluster/${local.platform_cluster_name}" = "shared"
    } : {},
    {
      "kubernetes.io/role/internal-elb" = "1"
    }
  )
}

# BASE Layer EKS Cluster
module "base_layer_eks" {
  count = var.base_cluster_enabled ? 1 : 0

  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = local.base_cluster_name
  cluster_version = var.base_cluster_config.version

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  # Managed Node Groups
  eks_managed_node_groups = var.base_cluster_config.enable_managed_nodes ? {
    for name, config in var.base_cluster_config.managed_node_groups : name => {
      name = "${var.project_name}-${name}"

      instance_types = config.instance_types
      capacity_type  = config.capacity_type

      min_size     = config.min_size
      max_size     = config.max_size
      desired_size = config.desired_size

      disk_size = config.disk_size
      disk_type = config.disk_type
      ami_type  = config.ami_type

      labels = config.labels

      taints = [
        for taint_name, taint_config in config.taints : {
          key    = taint_config.key
          value  = taint_config.value
          effect = taint_config.effect
        }
      ]

      tags = merge(var.tags, {
        ClusterType = "base-layer"
        NodeGroup   = name
      })
    }
  } : {}

  # Fargate profiles
  fargate_profiles = var.base_cluster_config.enable_fargate ? {
    for name, config in var.base_cluster_config.fargate_profiles : name => {
      name = "${var.project_name}-base-${name}"
      selectors = [
        for ns in config.namespace_selectors : {
          namespace = ns
          labels    = config.label_selectors
        }
      ]
    }
  } : {}

  # Cluster add-ons
  cluster_addons = {
    for addon_name, addon_config in var.cluster_addons : addon_name => {
      most_recent           = addon_config.most_recent
      addon_version        = addon_config.addon_version != "" ? addon_config.addon_version : null
      configuration_values = addon_config.configuration_values != "" ? addon_config.configuration_values : null
    }
  }

  tags = merge(var.tags, {
    ClusterType = "base-layer"
  })
}

# Platform Services EKS Cluster
module "platform_services_eks" {
  count = var.platform_cluster_enabled ? 1 : 0

  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = local.platform_cluster_name
  cluster_version = var.platform_cluster_config.version

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  # Managed Node Groups
  eks_managed_node_groups = var.platform_cluster_config.enable_managed_nodes ? {
    for name, config in var.platform_cluster_config.managed_node_groups : name => {
      name = "${var.project_name}-${name}"

      instance_types = config.instance_types
      capacity_type  = config.capacity_type

      min_size     = config.min_size
      max_size     = config.max_size
      desired_size = config.desired_size

      disk_size = config.disk_size
      disk_type = config.disk_type
      ami_type  = config.ami_type

      labels = config.labels

      taints = [
        for taint_name, taint_config in config.taints : {
          key    = taint_config.key
          value  = taint_config.value
          effect = taint_config.effect
        }
      ]

      tags = merge(var.tags, {
        ClusterType = "platform-services"
        NodeGroup   = name
      })
    }
  } : {}

  # Fargate profiles
  fargate_profiles = var.platform_cluster_config.enable_fargate ? {
    for name, config in var.platform_cluster_config.fargate_profiles : name => {
      name = "${var.project_name}-platform-${name}"
      selectors = [
        for ns in config.namespace_selectors : {
          namespace = ns
          labels    = config.label_selectors
        }
      ]
    }
  } : {}

  # Cluster add-ons
  cluster_addons = {
    for addon_name, addon_config in var.cluster_addons : addon_name => {
      most_recent           = addon_config.most_recent
      addon_version        = addon_config.addon_version != "" ? addon_config.addon_version : null
      configuration_values = addon_config.configuration_values != "" ? addon_config.configuration_values : null
    }
  }

  tags = merge(var.tags, {
    ClusterType = "platform-services"
  })
}

# IRSA Roles
module "irsa_roles" {
  for_each = var.enable_irsa ? var.irsa_roles : {}

  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${local.platform_cluster_name}-${each.key}-role"

  role_policy_arns = {
    for i, arn in each.value.policy_arns : "policy_${i}" => arn
  }

  oidc_providers = var.platform_cluster_enabled ? {
    platform = {
      provider_arn = module.platform_services_eks[0].oidc_provider_arn
      namespace_service_accounts = flatten([
        for ns in each.value.namespaces : [
          for sa in each.value.service_accounts : "${ns}:${sa}"
        ]
      ])
    }
  } : {}

  tags = var.tags
}
EOF

    # Create comprehensive outputs
    cat > terraform/modules/kubernetes/outputs.tf << 'EOF'
# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnets
}

output "nat_gateway_ids" {
  description = "IDs of the NAT gateways"
  value       = module.vpc.natgw_ids
}

# BASE Layer Cluster Outputs
output "base_cluster_enabled" {
  description = "Whether BASE layer cluster is enabled"
  value       = var.base_cluster_enabled
}

output "base_cluster_id" {
  description = "BASE layer EKS cluster ID"
  value       = var.base_cluster_enabled ? module.base_layer_eks[0].cluster_id : null
}

output "base_cluster_arn" {
  description = "BASE layer EKS cluster ARN"
  value       = var.base_cluster_enabled ? module.base_layer_eks[0].cluster_arn : null
}

output "base_cluster_endpoint" {
  description = "Endpoint for BASE layer EKS control plane"
  value       = var.base_cluster_enabled ? module.base_layer_eks[0].cluster_endpoint : null
}

output "base_cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data for BASE layer cluster"
  value       = var.base_cluster_enabled ? module.base_layer_eks[0].cluster_certificate_authority_data : null
  sensitive   = true
}

output "base_cluster_name" {
  description = "BASE layer cluster name"
  value       = var.base_cluster_enabled ? local.base_cluster_name : null
}

output "base_cluster_version" {
  description = "BASE layer cluster Kubernetes version"
  value       = var.base_cluster_enabled ? module.base_layer_eks[0].cluster_version : null
}

# Platform Services Cluster Outputs
output "platform_cluster_enabled" {
  description = "Whether platform services cluster is enabled"
  value       = var.platform_cluster_enabled
}

output "platform_cluster_id" {
  description = "Platform services EKS cluster ID"
  value       = var.platform_cluster_enabled ? module.platform_services_eks[0].cluster_id : null
}

output "platform_cluster_arn" {
  description = "Platform services EKS cluster ARN"
  value       = var.platform_cluster_enabled ? module.platform_services_eks[0].cluster_arn : null
}

output "platform_cluster_endpoint" {
  description = "Endpoint for platform services EKS control plane"
  value       = var.platform_cluster_enabled ? module.platform_services_eks[0].cluster_endpoint : null
}

output "platform_cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data for platform services cluster"
  value       = var.platform_cluster_enabled ? module.platform_services_eks[0].cluster_certificate_authority_data : null
  sensitive   = true
}

output "platform_cluster_name" {
  description = "Platform services cluster name"
  value       = var.platform_cluster_enabled ? local.platform_cluster_name : null
}

output "platform_cluster_version" {
  description = "Platform services cluster Kubernetes version"
  value       = var.platform_cluster_enabled ? module.platform_services_eks[0].cluster_version : null
}

# IRSA Role ARNs
output "irsa_role_arns" {
  description = "ARNs of the IRSA roles"
  value = {
    for role_name, role in module.irsa_roles : role_name => role.iam_role_arn
  }
}
EOF

    log "✅ Configurable AWS Terraform modules created"
}

# Create AWS environment configuration with parameter file
create_aws_environment_config() {
    log "Creating AWS environment configuration with flexible parameters..."

    # Convert PROJECT_ROOT to lowercase for naming
    local project_name_lower
    project_name_lower=$(echo "${PROJECT_ROOT}" | tr '[:upper:]' '[:lower:]')

    # Create the main.tf that uses the flexible module
    cat > terraform/environments/dev/main.tf << EOF
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "${project_name_lower}-terraform-state-${REGION}"
    key            = "dev/terraform.tfstate"
    region         = "${REGION}"
    encrypt        = true
    dynamodb_table = "${project_name_lower}-terraform-locks"
  }
}

provider "aws" {
  region = "${REGION}"

  default_tags {
    tags = {
      Environment   = "${ENVIRONMENT}"
      Project       = "${PROJECT_ROOT}"
      ManagedBy     = "terraform"
      Owner         = "platform-engineering"
      CloudProvider = "aws"
      Architecture  = "multi-cluster"
    }
  }
}

# Multi-cluster EKS deployment using variables
module "multi_cluster_eks" {
  source = "../../modules/kubernetes"

  # Basic configuration
  project_name = var.project_name
  environment  = var.environment
  region      = var.region

  # VPC configuration
  vpc_cidr                = var.vpc_cidr
  availability_zones_count = var.availability_zones_count
  private_subnets_count   = var.private_subnets_count
  public_subnets_count    = var.public_subnets_count

  # NAT Gateway configuration
  nat_gateway_count       = var.nat_gateway_count
  enable_nat_gateway      = var.enable_nat_gateway
  single_nat_gateway      = var.single_nat_gateway
  one_nat_gateway_per_az  = var.one_nat_gateway_per_az

  # Cluster configuration
  base_cluster_enabled     = var.base_cluster_enabled
  platform_cluster_enabled = var.platform_cluster_enabled

  base_cluster_config     = var.base_cluster_config
  platform_cluster_config = var.platform_cluster_config

  # Add-ons and IRSA
  cluster_addons = var.cluster_addons
  enable_irsa    = var.enable_irsa
  irsa_roles     = var.irsa_roles

  tags = var.common_tags
}
EOF

    # Create comprehensive variables.tf for the environment
    cat > terraform/environments/dev/variables.tf << 'EOF'
# Basic Configuration Variables
variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

# VPC Configuration Variables
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "availability_zones_count" {
  description = "Number of availability zones to use"
  type        = number
}

variable "private_subnets_count" {
  description = "Number of private subnets per AZ"
  type        = number
}

variable "public_subnets_count" {
  description = "Number of public subnets per AZ"
  type        = number
}

variable "nat_gateway_count" {
  description = "Number of NAT gateways"
  type        = number
}

variable "enable_nat_gateway" {
  description = "Enable NAT gateway"
  type        = bool
}

variable "single_nat_gateway" {
  description = "Use single NAT gateway for all private subnets"
  type        = bool
}

variable "one_nat_gateway_per_az" {
  description = "Use one NAT gateway per availability zone"
  type        = bool
}

# Cluster Configuration Variables
variable "base_cluster_enabled" {
  description = "Enable BASE layer cluster"
  type        = bool
}

variable "platform_cluster_enabled" {
  description = "Enable platform services cluster"
  type        = bool
}

variable "base_cluster_config" {
  description = "Configuration for BASE layer cluster"
  type = object({
    name               = string
    version            = string
    enable_fargate     = bool
    enable_managed_nodes = bool
    fargate_profiles   = map(object({
      namespace_selectors = list(string)
      label_selectors    = map(string)
    }))
    managed_node_groups = map(object({
      instance_types = list(string)
      capacity_type  = string
      min_size      = number
      max_size      = number
      desired_size  = number
      disk_size     = number
      disk_type     = string
      ami_type      = string
      labels        = map(string)
      taints = map(object({
        key    = string
        value  = string
        effect = string
      }))
    }))
  })
}

variable "platform_cluster_config" {
  description = "Configuration for platform services cluster"
  type = object({
    name               = string
    version            = string
    enable_fargate     = bool
    enable_managed_nodes = bool
    fargate_profiles   = map(object({
      namespace_selectors = list(string)
      label_selectors    = map(string)
    }))
    managed_node_groups = map(object({
      instance_types = list(string)
      capacity_type  = string
      min_size      = number
      max_size      = number
      desired_size  = number
      disk_size     = number
      disk_type     = string
      ami_type      = string
      labels        = map(string)
      taints = map(object({
        key    = string
        value  = string
        effect = string
      }))
    }))
  })
}

variable "cluster_addons" {
  description = "EKS cluster add-ons configuration"
  type = map(object({
    most_recent    = bool
    addon_version  = string
    configuration_values = string
  }))
}

variable "enable_irsa" {
  description = "Enable IAM Roles for Service Accounts"
  type        = bool
}

variable "irsa_roles" {
  description = "IRSA roles configuration"
  type = map(object({
    policy_arns = list(string)
    namespaces  = list(string)
    service_accounts = list(string)
  }))
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
}
EOF

    # Create the parameters file (terraform.tfvars) with all configuration options
    cat > terraform/environments/dev/terraform.tfvars << EOF
# ===================================================================
# FinPortIQ Platform - AWS Multi-Cluster Configuration
# ===================================================================
# This file contains all configurable parameters for the AWS infrastructure
# Modify values according to your requirements

# Basic Configuration
project_name = "${PROJECT_ROOT}"
environment  = "${ENVIRONMENT}"
region      = "${REGION}"

# ===================================================================
# VPC Configuration
# ===================================================================
vpc_cidr                = "10.0.0.0/16"
availability_zones_count = 3               # Number of AZs to use (2-6)
private_subnets_count   = 1                # Private subnets per AZ
public_subnets_count    = 1                # Public subnets per AZ

# NAT Gateway Configuration
nat_gateway_count       = 3                # Total number of NAT gateways
enable_nat_gateway      = true             # Enable NAT gateways
single_nat_gateway      = false            # Use single NAT for all private subnets
one_nat_gateway_per_az  = true             # Use one NAT per AZ (recommended for HA)

# ===================================================================
# Cluster Configuration
# ===================================================================
base_cluster_enabled     = true            # Enable BASE layer cluster
platform_cluster_enabled = true            # Enable platform services cluster

# ===================================================================
# BASE Layer Cluster Configuration
# ===================================================================
base_cluster_config = {
  name               = "base-layer"
  version            = "1.33"              # EKS version 1.33
  enable_fargate     = true                # Enable Fargate profiles
  enable_managed_nodes = true              # Enable managed node groups

  # Fargate profiles for BASE layer
  fargate_profiles = {
    base_components = {
      namespace_selectors = ["base-*"]     # All base-* namespaces
      label_selectors    = {}              # No specific label selectors
    }
  }

  # Managed node groups for BASE layer
  managed_node_groups = {
    base_compute = {
      instance_types = ["t3.medium", "t3.large"]  # Instance types for BASE workloads
      capacity_type  = "ON_DEMAND"                # ON_DEMAND or SPOT
      min_size      = 1                           # Minimum nodes
      max_size      = 10                          # Maximum nodes
      desired_size  = 3                           # Desired nodes
      disk_size     = 50                          # EBS disk size (GB)
      disk_type     = "gp3"                       # EBS disk type
      ami_type      = "AL2_x86_64"                # AMI type
      labels = {
        NodeGroup   = "base-layer"
        Environment = "${ENVIRONMENT}"
        WorkloadType = "base-components"
      }
      taints = {
        base_layer = {
          key    = "base-layer"
          value  = "true"
          effect = "NO_SCHEDULE"                   # Dedicated to BASE layer
        }
      }
    }
    base_memory_optimized = {
      instance_types = ["r5.large", "r5.xlarge"]  # Memory-optimized for data processing
      capacity_type  = "SPOT"                     # Use SPOT instances for cost savings
      min_size      = 0                           # Can scale to zero
      max_size      = 20                          # Allow high scale for data processing
      desired_size  = 2                           # Start with 2 nodes
      disk_size     = 100                         # Larger disk for data processing
      disk_type     = "gp3"
      ami_type      = "AL2_x86_64"
      labels = {
        NodeGroup   = "base-memory-optimized"
        Environment = "${ENVIRONMENT}"
        WorkloadType = "data-processing"
      }
      taints = {
        memory_optimized = {
          key    = "memory-optimized"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }
    }
  }
}

# ===================================================================
# Platform Services Cluster Configuration
# ===================================================================
platform_cluster_config = {
  name               = "platform-services"
  version            = "1.33"              # EKS version 1.33
  enable_fargate     = true                # Enable Fargate profiles
  enable_managed_nodes = true              # Enable managed node groups

  # Fargate profiles for platform services
  fargate_profiles = {
    platform_default = {
      namespace_selectors = ["default", "kube-system"]
      label_selectors    = {}
    }
    platform_services = {
      namespace_selectors = ["argocd", "crossplane-system", "monitoring"]
      label_selectors    = {}
    }
    ml_platform = {
      namespace_selectors = ["ml-*"]       # All ml-* namespaces
      label_selectors    = {}
    }
  }

  # Managed node groups for platform services
  managed_node_groups = {
    platform_general = {
      instance_types = ["t3.large", "t3.xlarge"]  # General purpose instances
      capacity_type  = "ON_DEMAND"                # Reliable for platform services
      min_size      = 1
      max_size      = 10
      desired_size  = 3
      disk_size     = 100                          # Larger disk for platform services
      disk_type     = "gp3"
      ami_type      = "AL2_x86_64"
      labels = {
        NodeGroup   = "platform-services"
        Environment = "${ENVIRONMENT}"
        WorkloadType = "platform-services"
      }
      taints = {}                                  # No taints - general purpose
    }
    ml_workloads = {
      instance_types = ["m5.large", "m5.xlarge", "m5.2xlarge"]  # Compute optimized for ML
      capacity_type  = "SPOT"                     # Cost-effective for ML training
      min_size      = 0                           # Can scale to zero when not needed
      max_size      = 50                          # Allow high scale for ML workloads
      desired_size  = 2
      disk_size     = 200                         # Large disk for ML datasets
      disk_type     = "gp3"
      ami_type      = "AL2_x86_64"
      labels = {
        NodeGroup   = "ml-workloads"
        Environment = "${ENVIRONMENT}"
        WorkloadType = "machine-learning"
      }
      taints = {
        ml_workload = {
          key    = "ml-workload"
          value  = "true"
          effect = "NO_SCHEDULE"                   # Dedicated to ML workloads
        }
      }
    }
    airflow_workers = {
      instance_types = ["c5.large", "c5.xlarge"]  # Compute optimized for Airflow
      capacity_type  = "ON_DEMAND"                # Reliable for workflow orchestration
      min_size      = 1
      max_size      = 20                          # Allow scaling for high workloads
      desired_size  = 2
      disk_size     = 50
      disk_type     = "gp3"
      ami_type      = "AL2_x86_64"
      labels = {
        NodeGroup   = "airflow-workers"
        Environment = "${ENVIRONMENT}"
        WorkloadType = "workflow-orchestration"
      }
      taints = {
        airflow = {
          key    = "airflow"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }
    }
  }
}

# ===================================================================
# EKS Add-ons Configuration
# ===================================================================
cluster_addons = {
  coredns = {
    most_recent           = true
    addon_version        = ""              # Use most recent
    configuration_values = ""
  }
  kube-proxy = {
    most_recent           = true
    addon_version        = ""
    configuration_values = ""
  }
  vpc-cni = {
    most_recent    = true
    addon_version = ""
    configuration_values = jsonencode({
      env = {
        ENABLE_PREFIX_DELEGATION = "true"
        WARM_PREFIX_TARGET       = "1"
        ENABLE_POD_ENI          = "true"    # Enable pod ENI for better networking
      }
    })
  }
  aws-ebs-csi-driver = {
    most_recent           = true
    addon_version        = ""
    configuration_values = jsonencode({
      defaultStorageClass = {
        enabled = true
      }
    })
  }
}

# ===================================================================
# IAM Roles for Service Accounts (IRSA) Configuration
# ===================================================================
enable_irsa = true

irsa_roles = {
  crossplane = {
    policy_arns      = ["arn:aws:iam::aws:policy/AdministratorAccess"]  # Full access for infrastructure management
    namespaces       = ["crossplane-system"]
    service_accounts = ["crossplane"]
  }
  argocd = {
    policy_arns      = ["arn:aws:iam::aws:policy/AdministratorAccess"]  # Full access for GitOps
    namespaces       = ["argocd"]
    service_accounts = ["argocd-server", "argocd-application-controller"]
  }
  airflow = {
    policy_arns = [
      "arn:aws:iam::aws:policy/AmazonS3FullAccess",                    # S3 access for data processing
      "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"                # EC2 read access
    ]
    namespaces       = ["airflow"]
    service_accounts = ["airflow-scheduler", "airflow-webserver", "airflow-worker"]
  }
  monitoring = {
    policy_arns = [
      "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess",              # CloudWatch metrics
      "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"                # EC2 monitoring
    ]
    namespaces       = ["monitoring"]
    service_accounts = ["prometheus", "grafana"]
  }
}

# ===================================================================
# Common Tags Applied to All Resources
# ===================================================================
common_tags = {
  Environment   = "${ENVIRONMENT}"
  Project       = "${PROJECT_ROOT}"
  ManagedBy     = "terraform"
  Owner         = "platform-engineering"
  CloudProvider = "aws"
  Architecture  = "multi-cluster"
  CostCenter    = "platform-engineering"
  Backup        = "required"
  Monitoring    = "enabled"
}
EOF

    # Create outputs for both clusters
    cat > terraform/environments/dev/outputs.tf << 'EOF'
# ===================================================================
# Infrastructure Outputs
# ===================================================================

# VPC Information
output "vpc_info" {
  description = "VPC configuration details"
  value = {
    vpc_id              = module.multi_cluster_eks.vpc_id
    vpc_cidr            = module.multi_cluster_eks.vpc_cidr_block
    private_subnet_ids  = module.multi_cluster_eks.private_subnet_ids
    public_subnet_ids   = module.multi_cluster_eks.public_subnet_ids
    nat_gateway_ids     = module.multi_cluster_eks.nat_gateway_ids
  }
}

# BASE Layer Cluster Outputs
output "base_cluster_info" {
  description = "BASE layer cluster information"
  value = module.multi_cluster_eks.base_cluster_enabled ? {
    enabled                = module.multi_cluster_eks.base_cluster_enabled
    cluster_id            = module.multi_cluster_eks.base_cluster_id
    cluster_name          = module.multi_cluster_eks.base_cluster_name
    cluster_endpoint      = module.multi_cluster_eks.base_cluster_endpoint
    cluster_version       = module.multi_cluster_eks.base_cluster_version
  } : null
}

output "base_cluster_auth" {
  description = "BASE layer cluster authentication data"
  value = module.multi_cluster_eks.base_cluster_enabled ? {
    certificate_authority_data = module.multi_cluster_eks.base_cluster_certificate_authority_data
  } : null
  sensitive = true
}

# Platform Services Cluster Outputs
output "platform_cluster_info" {
  description = "Platform services cluster information"
  value = module.multi_cluster_eks.platform_cluster_enabled ? {
    enabled                = module.multi_cluster_eks.platform_cluster_enabled
    cluster_id            = module.multi_cluster_eks.platform_cluster_id
    cluster_name          = module.multi_cluster_eks.platform_cluster_name
    cluster_endpoint      = module.multi_cluster_eks.platform_cluster_endpoint
    cluster_version       = module.multi_cluster_eks.platform_cluster_version
  } : null
}

output "platform_cluster_auth" {
  description = "Platform services cluster authentication data"
  value = module.multi_cluster_eks.platform_cluster_enabled ? {
    certificate_authority_data = module.multi_cluster_eks.platform_cluster_certificate_authority_data
  } : null
  sensitive = true
}

# IRSA Role ARNs
output "irsa_role_arns" {
  description = "ARNs of IAM roles for service accounts"
  value       = module.multi_cluster_eks.irsa_role_arns
}

# Kubectl Commands for Cluster Access
output "kubectl_commands" {
  description = "Commands to configure kubectl access"
  value = {
    base_cluster = module.multi_cluster_eks.base_cluster_enabled ?
      "aws eks update-kubeconfig --region ${var.region} --name ${module.multi_cluster_eks.base_cluster_name} --alias base-layer" : null
    platform_cluster = module.multi_cluster_eks.platform_cluster_enabled ?
      "aws eks update-kubeconfig --region ${var.region} --name ${module.multi_cluster_eks.platform_cluster_name} --alias platform-services" : null
  }
}
EOF

# Create documentation for the parameterized setup
create_configuration_documentation() {
    log "Creating configuration documentation..."

    # Create a comprehensive README for the terraform configuration
    cat > terraform/environments/dev/README.md << 'EOF'
# FinPortIQ AWS Multi-Cluster Configuration

This directory contains a fully parameterized Terraform configuration for deploying a multi-cluster AWS infrastructure optimized for the FinPortIQ platform.

## 🏗️ Architecture Overview

```
┌─────────────────────────────────┐  ┌─────────────────────────────────┐
│        BASE App Layer          │  │      Platform Services         │
│     EKS Cluster (1.33)         │  │     EKS Cluster (1.33)         │
├─────────────────────────────────┤  ├─────────────────────────────────┤
│  Node Groups:                   │  │  Node Groups:                   │
│  ├── base_compute (t3.medium)   │  │  ├── platform_general (t3.large)│
│  └── base_memory (r5.large)     │  │  ├── ml_workloads (m5.large)    │
│                                 │  │  └── airflow_workers (c5.large) │
│  Fargate:                       │  │                                 │
│  └── base-* namespaces          │  │  Fargate:                       │
│                                 │  │  ├── argocd, monitoring         │
│  Components:                    │  │  └── ml-* namespaces            │
│  ├── 14 BASE layer components   │  │                                 │
│  └── Isolated with taints       │  │  Services:                      │
└─────────────────────────────────┘  │  ├── ArgoCD (GitOps)            │
                                     │  ├── Airflow (Orchestration)    │
                                     │  ├── Crossplane (IaC)           │
                                     │  ├── ML Platform                │
                                     │  └── Monitoring Stack           │
                                     └─────────────────────────────────┘
```

## 📋 Quick Configuration Guide

### 1. Basic Settings
```hcl
project_name = "platform-services"
environment  = "dev"
region      = "us-east-1"
```

### 2. VPC Configuration
```hcl
vpc_cidr                = "10.0.0.0/16"    # VPC CIDR block
availability_zones_count = 3               # Number of AZs (2-6)
private_subnets_count   = 1                # Private subnets per AZ
public_subnets_count    = 1                # Public subnets per AZ

# NAT Gateway Options:
nat_gateway_count       = 3                # Total NAT gateways
single_nat_gateway      = false            # true = single NAT for all
one_nat_gateway_per_az  = true             # true = one NAT per AZ (HA)
```

### 3. Cluster Enablement
```hcl
base_cluster_enabled     = true            # Enable BASE layer cluster
platform_cluster_enabled = true            # Enable platform services cluster
```

### 4. EKS Version
Both clusters use **EKS 1.33** by default:
```hcl
base_cluster_config = {
  version = "1.33"                         # Latest EKS version
  # ...
}
platform_cluster_config = {
  version = "1.33"                         # Latest EKS version
  # ...
}
```

## 🎛️ Advanced Configuration Options

### Instance Type Selection

**BASE Layer Cluster:**
- `base_compute`: General workloads (t3.medium, t3.large)
- `base_memory_optimized`: Data processing (r5.large, r5.xlarge)

**Platform Services Cluster:**
- `platform_general`: Platform services (t3.large, t3.xlarge)
- `ml_workloads`: ML training/inference (m5.large, m5.xlarge, m5.2xlarge)
- `airflow_workers`: Workflow orchestration (c5.large, c5.xlarge)

### Capacity Types
- **ON_DEMAND**: Reliable, always available
- **SPOT**: Cost-effective, can be interrupted

### Node Group Scaling
```hcl
min_size     = 1    # Minimum nodes
max_size     = 10   # Maximum nodes
desired_size = 3    # Starting nodes
```

### Taints and Tolerations
Workload isolation using Kubernetes taints:
- BASE layer: `base-layer=true:NoSchedule`
- ML workloads: `ml-workload=true:NoSchedule`
- Airflow: `airflow=true:NoSchedule`

## 🔧 Common Configuration Scenarios

### Scenario 1: Cost-Optimized Development
```hcl
# Reduce NAT gateways
single_nat_gateway = true
nat_gateway_count  = 1

# Use SPOT instances
managed_node_groups = {
  base_compute = {
    capacity_type = "SPOT"
    desired_size  = 1
    # ...
  }
}
```

### Scenario 2: High-Availability Production
```hcl
# Multiple NAT gateways for HA
one_nat_gateway_per_az = true
nat_gateway_count      = 3

# ON_DEMAND instances for reliability
managed_node_groups = {
  platform_general = {
    capacity_type = "ON_DEMAND"
    desired_size  = 5
    # ...
  }
}
```

### Scenario 3: ML-Heavy Workloads
```hcl
# Larger ML node group
managed_node_groups = {
  ml_workloads = {
    instance_types = ["m5.2xlarge", "m5.4xlarge"]
    max_size      = 100
    desired_size  = 10
    # ...
  }
}
```

## 🚀 Deployment Commands

### 1. Initialize Terraform
```bash
cd terraform/environments/dev
terraform init
```

### 2. Plan Infrastructure
```bash
terraform plan -var-file="terraform.tfvars"
```

### 3. Deploy Infrastructure
```bash
terraform apply -var-file="terraform.tfvars"
```

### 4. Configure kubectl Access
```bash
# BASE layer cluster
aws eks update-kubeconfig --region us-east-1 --name platform-services-base-layer-dev --alias base-layer

# Platform services cluster
aws eks update-kubeconfig --region us-east-1 --name platform-services-platform-services-dev --alias platform-services
```

## 📊 Cost Optimization Tips

1. **Use SPOT instances** for non-critical workloads
2. **Enable cluster autoscaler** to scale nodes based on demand
3. **Use single NAT gateway** for development environments
4. **Right-size instance types** based on actual usage
5. **Enable Fargate** for lightweight, event-driven workloads

## 🔒 Security Features

1. **Private subnets** for all worker nodes
2. **IAM Roles for Service Accounts (IRSA)** for secure AWS access
3. **Network isolation** using security groups
4. **Workload isolation** using taints and tolerations
5. **Separate clusters** for different security zones

## 🔍 Monitoring and Observability

The configuration includes IRSA roles for:
- **CloudWatch** monitoring integration
- **Prometheus** metrics collection
- **Grafana** dashboard access
- **AWS X-Ray** distributed tracing

## 📚 Additional Resources

- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [EKS Managed Node Groups](https://docs.aws.amazon.com/eks/latest/userguide/managed-node-groups.html)
- [AWS Fargate for EKS](https://docs.aws.amazon.com/eks/latest/userguide/fargate.html)

## 🆘 Troubleshooting

### Common Issues:

1. **Insufficient IAM permissions**: Ensure your AWS profile has sufficient permissions
2. **VPC CIDR conflicts**: Check for existing VPCs with overlapping CIDRs
3. **Instance type availability**: Some instance types may not be available in all regions
4. **EKS version**: Ensure EKS 1.33 is available in your selected region

### Getting Help:

1. Check Terraform output for specific error messages
2. Review AWS CloudFormation events in the console
3. Verify IAM permissions using AWS CloudTrail
4. Check AWS service limits and quotas
EOF

    log "✅ Configuration documentation created"
}
}

# Create AWS Crossplane configuration
create_aws_crossplane_config() {
    log "Creating AWS Crossplane configuration..."

    # Create providers directory if it doesn't exist
    mkdir -p crossplane/providers

    # AWS Provider Configuration
    cat > crossplane/providers/aws-provider.yaml << 'EOF'
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-aws-ec2
spec:
  package: xpkg.upbound.io/upbound/provider-aws-ec2:v0.47.0
---
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-aws-rds
spec:
  package: xpkg.upbound.io/upbound/provider-aws-rds:v0.47.0
---
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-aws-s3
spec:
  package: xpkg.upbound.io/upbound/provider-aws-s3:v0.47.0
---
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-aws-iam
spec:
  package: xpkg.upbound.io/upbound/provider-aws-iam:v0.47.0
EOF

    # Provider Config with IRSA
    cat > crossplane/providers/aws-providerconfig.yaml << EOF
apiVersion: aws.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: IRSA
  region: ${REGION}
EOF

    # Create AWS-specific compositions
    create_aws_crossplane_compositions

    log "✅ AWS Crossplane configuration created"
}

create_aws_crossplane_compositions() {
    log "Creating AWS Crossplane compositions..."

    # PostgreSQL Database Composition
    cat > crossplane/compositions/aws-postgresql.yaml << EOF
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: aws-postgresql
  labels:
    provider: aws
    service: postgresql
    crossplane.io/xrd: xdatabases.finportiq.io
spec:
  compositeTypeRef:
    apiVersion: finportiq.io/v1alpha1
    kind: XDatabase

  resources:
    - name: db-subnet-group
      base:
        apiVersion: rds.aws.upbound.io/v1beta1
        kind: SubnetGroup
        spec:
          forProvider:
            region: ${REGION}
            subnetIds: []
            tags:
              Name: ""
              Environment: ""
              Project: ""
      patches:
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.name
          toFieldPath: metadata.name
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.subnetIds
          toFieldPath: spec.forProvider.subnetIds
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.environment
          toFieldPath: spec.forProvider.tags.Environment
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.project
          toFieldPath: spec.forProvider.tags.Project

    - name: db-instance
      base:
        apiVersion: rds.aws.upbound.io/v1beta1
        kind: Instance
        spec:
          forProvider:
            region: ${REGION}
            instanceClass: db.t3.micro
            engine: postgres
            engineVersion: "15.4"
            allocatedStorage: 20
            maxAllocatedStorage: 100
            storageType: gp3
            storageEncrypted: true
            multiAz: false
            publiclyAccessible: false
            autoMinorVersionUpgrade: true
            deletionProtection: false
            skipFinalSnapshot: true
            vpcSecurityGroupIds: []
            dbName: ""
            username: postgres
            passwordSecretRef:
              namespace: crossplane-system
              name: ""
              key: password
            tags:
              Name: ""
              Environment: ""
              Project: ""
          writeConnectionSecretsToNamespace: crossplane-system
      patches:
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.name
          toFieldPath: metadata.name
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.name
          toFieldPath: spec.forProvider.dbName
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.name
          toFieldPath: spec.forProvider.passwordSecretRef.name
          transforms:
            - type: string
              string:
                fmt: "%s-password"
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.size
          toFieldPath: spec.forProvider.instanceClass
          transforms:
            - type: map
              map:
                small: db.t3.micro
                medium: db.t3.small
                large: db.r5.large
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.storageSize
          toFieldPath: spec.forProvider.allocatedStorage
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.environment
          toFieldPath: spec.forProvider.tags.Environment
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.project
          toFieldPath: spec.forProvider.tags.Project
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.subnetGroupName
          toFieldPath: spec.forProvider.dbSubnetGroupName
EOF

    # S3 Bucket Composition
    cat > crossplane/compositions/aws-s3.yaml << EOF
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: aws-s3-bucket
  labels:
    provider: aws
    service: s3
    crossplane.io/xrd: xobjectstorages.finportiq.io
spec:
  compositeTypeRef:
    apiVersion: finportiq.io/v1alpha1
    kind: XObjectStorage

  resources:
    - name: s3-bucket
      base:
        apiVersion: s3.aws.upbound.io/v1beta1
        kind: Bucket
        spec:
          forProvider:
            region: ${REGION}
            tags:
              Name: ""
              Environment: ""
              Project: ""
      patches:
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.name
          toFieldPath: metadata.name
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.environment
          toFieldPath: spec.forProvider.tags.Environment
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.project
          toFieldPath: spec.forProvider.tags.Project

    - name: bucket-versioning
      base:
        apiVersion: s3.aws.upbound.io/v1beta1
        kind: BucketVersioning
        spec:
          forProvider:
            region: ${REGION}
            bucketSelector:
              matchControllerRef: true
            versioningConfiguration:
              - status: Enabled
      patches:
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.name
          toFieldPath: metadata.name
          transforms:
            - type: string
              string:
                fmt: "%s-versioning"

    - name: bucket-server-side-encryption
      base:
        apiVersion: s3.aws.upbound.io/v1beta1
        kind: BucketServerSideEncryptionConfiguration
        spec:
          forProvider:
            region: ${REGION}
            bucketSelector:
              matchControllerRef: true
            rule:
              - applyServerSideEncryptionByDefault:
                  - sseAlgorithm: AES256
      patches:
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.name
          toFieldPath: metadata.name
          transforms:
            - type: string
              string:
                fmt: "%s-encryption"
EOF

    log "✅ AWS Crossplane compositions created"
}

# Create AWS-specific Helm values
create_aws_helm_values() {
    log "Creating AWS-specific Helm values..."

    # Convert PROJECT_ROOT to lowercase for naming
    local project_name_lower
    project_name_lower=$(echo "${PROJECT_ROOT}" | tr '[:upper:]' '[:lower:]')

    # Airflow values for AWS
    mkdir -p "helm-charts/platform-services/airflow/values"
    cat > "helm-charts/platform-services/airflow/values/values-dev-aws.yaml" << EOF
# Airflow values for AWS
global:
  cloudProvider: aws
  region: ${REGION}

airflow:
  image:
    repository: apache/airflow
    tag: 2.8.4

  # Executor configuration
  executor: KubernetesExecutor

  # Database configuration (using external PostgreSQL)
  postgresql:
    enabled: false

  externalDatabase:
    type: postgres
    host: postgresql-primary.postgresql.svc.cluster.local
    port: 5432
    database: airflow
    user: airflow

  # Storage configuration
  persistence:
    enabled: true
    storageClass: gp3
    size: 100Gi

  # Web server
  webserver:
    replicas: 2
    resources:
      limits:
        cpu: 2
        memory: 4Gi
      requests:
        cpu: 1
        memory: 2Gi

  # Scheduler
  scheduler:
    replicas: 1
    resources:
      limits:
        cpu: 2
        memory: 4Gi
      requests:
        cpu: 1
        memory: 2Gi

  # Workers (for KubernetesExecutor)
  workers:
    resources:
      limits:
        cpu: 2
        memory: 4Gi
      requests:
        cpu: 1
        memory: 2Gi

  # Service configuration
  service:
    type: LoadBalancer
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: nlb
      service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing

  # Node selector for AWS
  nodeSelector:
    kubernetes.io/os: linux

  # Tolerations for Fargate if needed
  tolerations: []
EOF

    # PostgreSQL values for AWS
    mkdir -p "helm-charts/platform-services/postgresql/values"
    cat > "helm-charts/platform-services/postgresql/values/values-dev-aws.yaml" << EOF
# PostgreSQL values for AWS
global:
  cloudProvider: aws
  region: ${REGION}
  storageClass: gp3

postgresql:
  architecture: replication
  auth:
    postgresPassword: changeme-in-production
    username: ${project_name_lower}
    password: changeme-in-production
    database: ${project_name_lower}

  primary:
    persistence:
      enabled: true
      storageClass: gp3
      size: 200Gi
    resources:
      limits:
        cpu: 4
        memory: 8Gi
      requests:
        cpu: 2
        memory: 4Gi
    nodeSelector:
      kubernetes.io/os: linux

  readReplicas:
    replicaCount: 2
    persistence:
      enabled: true
      storageClass: gp3
      size: 200Gi
    resources:
      limits:
        cpu: 2
        memory: 4Gi
      requests:
        cpu: 1
        memory: 2Gi
    nodeSelector:
      kubernetes.io/os: linux

  metrics:
    enabled: true
    resources:
      limits:
        cpu: 250m
        memory: 256Mi
      requests:
        cpu: 100m
        memory: 128Mi
EOF

    # Kafka values for AWS
    mkdir -p "helm-charts/platform-services/kafka/values"
    cat > "helm-charts/platform-services/kafka/values/values-dev-aws.yaml" << EOF
# Kafka values for AWS
global:
  cloudProvider: aws
  region: ${REGION}
  storageClass: gp3

kafka:
  version: 3.7.0
  replicas: 3

  storage:
    type: persistent-claim
    size: 100Gi
    storageClass: gp3

  resources:
    requests:
      memory: 2Gi
      cpu: 1
    limits:
      memory: 4Gi
      cpu: 2

  config:
    offsets.topic.replication.factor: 3
    transaction.state.log.replication.factor: 3
    transaction.state.log.min.isr: 2
    default.replication.factor: 3
    min.insync.replicas: 2

  nodeSelector:
    kubernetes.io/os: linux

zookeeper:
  replicas: 3
  storage:
    type: persistent-claim
    size: 50Gi
    storageClass: gp3
  resources:
    requests:
      memory: 1Gi
      cpu: 500m
    limits:
      memory: 2Gi
      cpu: 1
  nodeSelector:
    kubernetes.io/os: linux
EOF

    log "✅ AWS-specific Helm values created"
}

# Create AWS-specific Kustomize overlays for BASE layer
create_aws_base_overlays() {
    log "Creating AWS-specific Kustomize overlays for BASE layer..."

    # List of BASE layer components
    local base_components=(
        "data-ingestion" "data-control" "data-distribution" "data-quality"
        "data-security" "data-storage" "data-streaming" "event-coordination"
        "feature-engineering" "metadata-discovery" "multimodal-processing"
        "pipeline-management" "quality-monitoring" "schema-contracts"
    )

    for component in "${base_components[@]}"; do
        log "Creating AWS overlay for ${component}..."

        # Create AWS-specific overlay directory
        mkdir -p "kustomize/base-layer/${component}/overlays/aws"

        # Create AWS-specific kustomization.yaml
        cat > "kustomize/base-layer/${component}/overlays/aws/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

# AWS-specific patches
patches:
  - target:
      kind: Deployment
    patch: |-
      - op: add
        path: /spec/template/spec/containers/0/env/-
        value:
          name: CLOUD_PROVIDER
          value: aws
      - op: add
        path: /spec/template/spec/containers/0/env/-
        value:
          name: AWS_REGION
          value: ${REGION}
      - op: add
        path: /spec/template/spec/nodeSelector
        value:
          kubernetes.io/os: linux
          node.kubernetes.io/instance-type: t3.medium

  - target:
      kind: PersistentVolumeClaim
    patch: |-
      - op: replace
        path: /spec/storageClassName
        value: gp3

  - target:
      kind: Service
      name: ".*-service"
    patch: |-
      - op: add
        path: /metadata/annotations
        value:
          service.beta.kubernetes.io/aws-load-balancer-type: nlb

# AWS-specific labels
commonLabels:
  cloud.provider: aws
  cloud.region: ${REGION}
  base.io/provider: aws

# AWS-specific configuration
configMapGenerator:
  - name: ${component}-aws-config
    literals:
      - CLOUD_PROVIDER=aws
      - AWS_REGION=${REGION}
      - STORAGE_CLASS=gp3
      - LOAD_BALANCER_TYPE=nlb
      - NODE_SELECTOR=t3.medium
EOF

        log "Created AWS overlay for ${component}"
    done

    log "✅ AWS-specific BASE layer overlays created"
}

# Create AWS-specific ArgoCD applications
create_aws_argocd_apps() {
    log "Creating AWS-specific ArgoCD applications..."

    # Create necessary directories first
    mkdir -p argocd/projects
    mkdir -p argocd/applications/infrastructure
    mkdir -p argocd/applications/base-layer
    mkdir -p argocd/applications/platform-services
    mkdir -p argocd/applications/ml-platform

    # Create infrastructure project
    cat > argocd/projects/aws-infrastructure-project.yaml << EOF
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: aws-infrastructure
  namespace: argocd
spec:
  description: "AWS Infrastructure management with Crossplane"
  sourceRepos:
  - '${BASE_LAYER_REPO_URL}'
  - 'https://charts.crossplane.io/stable'
  - 'https://charts.jetstack.io'

  destinations:
  - namespace: 'crossplane-system'
    server: https://kubernetes.default.svc
  - namespace: 'cert-manager'
    server: https://kubernetes.default.svc
  - namespace: 'aws-*'
    server: https://kubernetes.default.svc

  clusterResourceWhitelist:
  - group: '*'
    kind: '*'

  namespaceResourceWhitelist:
  - group: '*'
    kind: '*'

  roles:
  - name: aws-admin
    description: "AWS infrastructure administrators"
    policies:
    - p, proj:aws-infrastructure:aws-admin, applications, *, aws-infrastructure/*, allow
    groups:
    - platform-engineering
EOF

    # Crossplane Core Application
    cat > argocd/applications/infrastructure/crossplane-core-aws.yaml << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: crossplane-core-aws
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
  project: aws-infrastructure
  source:
    chart: crossplane
    repoURL: https://charts.crossplane.io/stable
    targetRevision: 1.14.0
    helm:
      parameters:
      - name: args
        value: '{"--enable-environment-configs"}'
      - name: resourcesCrossplane.limits.cpu
        value: "1"
      - name: resourcesCrossplane.limits.memory
        value: "2Gi"
      - name: resourcesCrossplane.requests.cpu
        value: "500m"
      - name: resourcesCrossplane.requests.memory
        value: "1Gi"
  destination:
    server: https://kubernetes.default.svc
    namespace: crossplane-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - ServerSideApply=true
EOF

    # AWS Providers Application
    cat > argocd/applications/infrastructure/crossplane-aws-providers.yaml << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: crossplane-aws-providers
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "2"
spec:
  project: aws-infrastructure
  source:
    repoURL: ${BASE_LAYER_REPO_URL}
    path: platform-services/crossplane/providers
    targetRevision: HEAD
    directory:
      include: "aws-*"
  destination:
    server: https://kubernetes.default.svc
    namespace: crossplane-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - Replace=true
EOF

    # AWS Compositions Application
    cat > argocd/applications/infrastructure/crossplane-aws-compositions.yaml << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: crossplane-aws-compositions
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "3"
spec:
  project: aws-infrastructure
  source:
    repoURL: ${BASE_LAYER_REPO_URL}
    path: platform-services/crossplane/compositions
    targetRevision: HEAD
    directory:
      include: "aws-*"
  destination:
    server: https://kubernetes.default.svc
    namespace: crossplane-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
      - Replace=true
EOF

    # BASE layer applications with AWS overlays
    local base_components=(
        "data-ingestion" "data-control" "data-distribution" "data-quality"
        "data-security" "data-storage" "data-streaming" "event-coordination"
        "feature-engineering" "metadata-discovery" "multimodal-processing"
        "pipeline-management" "quality-monitoring" "schema-contracts"
    )

    for component in "${base_components[@]}"; do
        cat > "argocd/applications/base-layer/${component}-aws.yaml" << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${component}-aws
  namespace: argocd
  labels:
    app.kubernetes.io/name: ${component}
    app.kubernetes.io/part-of: base-system
    base.io/category: ${component//-/_}
    base.io/provider: aws
spec:
  project: base-layer
  source:
    repoURL: ${BASE_LAYER_REPO_URL}
    path: platform-services/kustomize/base-layer/${component}/overlays/aws
    targetRevision: HEAD
  destination:
    server: https://kubernetes.default.svc
    namespace: base-${component}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
      - ApplyOutOfSyncOnly=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
  revisionHistoryLimit: 3
EOF
    done

    log "✅ AWS-specific ArgoCD applications created"
}

# ============================================================================
# GITOPS PLATFORM DEPLOYMENT FUNCTIONS
# Integrated from deploy-aws-platform.sh
# ============================================================================

check_k8s_prerequisites() {
    log_info "Checking Kubernetes prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    log "Prerequisites check passed"
}

deploy_wave_1_infrastructure() {
    log_info "🌊 Wave 1: Infrastructure (Crossplane + AWS Provider)"
    
    # Deploy Crossplane infrastructure applications
    kubectl apply -f platform-services/argocd/applications/infrastructure/ || log_warning "Some infrastructure apps may not exist yet"
    
    # Wait for Crossplane to be ready
    log_info "Waiting for Crossplane to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/crossplane -n crossplane-system || true
    
    log "Wave 1 completed"
}

deploy_wave_2_platform_services() {
    log_info "🌊 Wave 2: Platform Services (Airflow + Monitoring)"
    
    # Deploy platform services using correct projects
    kubectl apply -f platform-services/argocd/applications/platform-services/airflow-app.yaml || log_warning "Airflow app may not exist yet"
    kubectl apply -f platform-services/argocd/applications/platform-services/monitoring-stack-app.yaml || log_warning "Monitoring app may not exist yet"
    
    # Deploy Argo Workflows and Events
    kubectl apply -f platform-services/argocd/applications/workflow-apps/ || log_warning "Some workflow apps may not exist yet"
    
    log "Wave 2 completed"
}

deploy_wave_3_data_ingestion() {
    log_info "🌊 Wave 3: Data Ingestion Layer (AWS Provider)"
    
    # Deploy data ingestion with AWS configurations
    # This references your data_ingestion/ folder configs with AWS overlays
    kubectl apply -f platform-services/argocd/applications/base-layer/data-ingestion-aws.yaml || log_warning "Data ingestion AWS app may not exist yet"
    
    # Also deploy individual components that reference data_ingestion/ folders
    kubectl apply -f platform-services/argocd/applications/base-layer/data-ingestion-app.yaml || log_warning "Data ingestion app may not exist yet"
    
    log "Wave 3 completed"
}

deploy_wave_4_ml_platform() {
    log_info "🌊 Wave 4: ML Platform (ml-apps project)"
    
    # Deploy ML applications using correct project
    kubectl apply -f platform-services/argocd/applications/ml-platform/ || log_warning "Some ML apps may not exist yet"
    
    log "Wave 4 completed"
}

deploy_automated_applicationsets() {
    log_info "🤖 Deploying Automated ApplicationSets"
    
    # Deploy the automated ApplicationSets for wave management
    kubectl apply -f platform-services/argocd/applicationsets/automated-platform-deployment.yaml || log_warning "ApplicationSets may not exist yet"
    
    log "ApplicationSets deployed"
}

monitor_deployments() {
    log_info "📊 Monitoring deployment progress..."
    
    # Monitor for 5 minutes
    for i in {1..10}; do
        echo ""
        echo "=== Monitoring Iteration $i ==="
        
        # Check applications by project
        echo "📋 Data Ingestion (base-layer project):"
        kubectl get applications -n argocd -l app.kubernetes.io/name=data-ingestion -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status 2>/dev/null || echo "No data ingestion apps found"
        
        echo ""
        echo "🤖 ML Platform (ml-apps project):"
        kubectl get applications -n argocd | grep -E "(mlflow|seldon|kubeflow)" || echo "No ML apps found"
        
        echo ""
        echo "🔧 Platform Services (workflow-apps, monitoring-apps projects):"
        kubectl get applications -n argocd | grep -E "(airflow|monitoring|argo)" || echo "No platform services found"
        
        echo ""
        echo "☁️  Infrastructure (orchestration-apps project):"
        kubectl get applications -n argocd | grep -E "(crossplane)" || echo "No infrastructure apps found"
        
        sleep 30
    done
}

validate_aws_deployment() {
    log_info "🔍 Validating AWS deployment..."
    
    # Check namespaces
    echo "📦 Checking namespaces:"
    kubectl get namespaces | grep -E "(base-data-ingestion|mlflow|seldon|airflow|monitoring|crossplane)" || true
    
    # Check AWS-specific resources
    echo ""
    echo "☁️  Checking AWS-specific configurations:"
    kubectl get configmap -n base-data-ingestion data-ingestion-aws-config -o yaml 2>/dev/null || echo "AWS config not found"
    
    # Check if pods are running with AWS configurations
    echo ""
    echo "🏃 Checking running pods with AWS provider:"
    kubectl get pods -A -l cloud.provider=aws 2>/dev/null || echo "No AWS pods found yet"
    
    log "Validation completed"
}

display_access_info() {
    log_info "🎯 Platform Access Information"
    
    echo ""
    log "🎉 AWS Platform Deployment Complete!"
    echo "====================================="
    echo ""
    
    echo "📊 Project Structure:"
    echo "├── base-layer project"
    echo "│   └── data_ingestion/ folder configs with AWS overlays"
    echo "├── ml-apps project"  
    echo "│   ├── MLflow"
    echo "│   ├── Seldon Core"
    echo "│   └── Kubeflow"
    echo "├── workflow-apps project"
    echo "│   ├── Airflow"
    echo "│   └── Argo Workflows"
    echo "├── monitoring-apps project"
    echo "│   └── Prometheus + Grafana"
    echo "└── orchestration-apps project"
    echo "    └── Crossplane + AWS Provider"
    echo ""
    
    echo "🔐 Access URLs:"
    echo "ArgoCD: kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "Airflow: kubectl port-forward svc/airflow-webserver -n airflow 8080:8080"  
    echo "MLflow: kubectl port-forward svc/mlflow -n mlflow 5000:5000"
    echo "Grafana: kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80"
    echo ""
    
    echo "✅ Features Deployed:"
    echo "🔄 GitOps with ArgoCD ApplicationSets"
    echo "🌪️  Airflow orchestration for automation"
    echo "☁️  AWS provider configurations"
    echo "📊 Data ingestion referencing data_ingestion/ configs"
    echo "🤖 ML platform with AWS integrations"
    echo "📈 Monitoring and observability"
    echo ""
    
    log "Platform ready for AWS operations!"
}

deploy_gitops_platform() {
    log ""
    log "🏗️  GitOps Platform Deployment with Automated Waves"
    log "=================================================="
    
    check_k8s_prerequisites
    deploy_wave_1_infrastructure
    deploy_wave_2_platform_services
    deploy_wave_3_data_ingestion
    deploy_wave_4_ml_platform
    deploy_automated_applicationsets
    monitor_deployments
    validate_aws_deployment
    display_access_info
    
    log "🎉 GitOps Platform deployment completed!"
}

# ============================================================================
# END GITOPS PLATFORM DEPLOYMENT FUNCTIONS
# ============================================================================

main() {
    log "========================================="
    log "AWS Provider Configuration"
    log "========================================="

    # Parse arguments (region should be passed from main script)
    parse_args "$@"

    log_info "Configuring AWS provider for region: $REGION"
    log_info "Project: $PROJECT_ROOT"
    log_info "Environment: $ENVIRONMENT"
    log_info "Cluster: $CLUSTER_NAME"

    # AWS-specific validations and setup
    validate_aws_credentials

    # Create AWS configurations
    create_aws_terraform_modules
    create_aws_environment_config
    create_configuration_documentation
    create_aws_crossplane_config
    create_aws_helm_values
    create_aws_base_overlays
    create_aws_argocd_apps

    log ""
    log "========================================="
    log "AWS Provider Configuration Completed"
    log "========================================="
    log ""
    log "CREATED:"
    log "========="
    log "✅ Terraform: Multi-cluster EKS (BASE layer + Platform services)"
    log "✅ Configuration: Fully parameterized terraform.tfvars"
    log "✅ Crossplane: AWS providers (EC2, RDS, S3, IAM)"
    log "✅ Helm: AWS-optimized values (gp3 storage, NLB)"
    log "✅ Kustomize: AWS overlays for all BASE components"
    log "✅ ArgoCD: Multi-cluster applications and projects"
    log "✅ IRSA: IAM roles for service accounts configured"
    log ""
    log "CONFIGURATION OPTIONS:"
    log "====================="
    log "📝 Edit terraform/environments/dev/terraform.tfvars to customize:"
    log "   • EKS version: 1.33 (configurable)"
    log "   • Instance types: t3.medium, t3.large, r5.large, etc."
    log "   • NAT gateways: 1-3 (configurable per AZ)"
    log "   • Subnets: Private/public count per AZ"
    log "   • Fargate vs Managed nodes: Both enabled"
    log "   • Node groups: Dedicated for BASE, Platform, ML"
    log "   • Autoscaling: Min/max/desired sizes"
    log "   • Taints/tolerations: Workload isolation"
    log ""
    log "MULTI-CLUSTER ARCHITECTURE:"
    log "==========================="
    log "🏗️  BASE Layer Cluster:"
    log "   • Dedicated to 14 BASE components"
    log "   • Isolated with taints for security"
    log "   • Memory-optimized nodes for data processing"
    log ""
    log "🏗️  Platform Services Cluster:"
    log "   • ArgoCD, Airflow, ML platform"
    log "   • Multiple node groups for different workloads"
    log "   • Fargate for lightweight services"
    log ""
    log "NEXT STEPS:"
    log "==========="
    log "1. 📝 Review/modify: terraform/environments/dev/terraform.tfvars"
    log "2. 🚀 Deploy infrastructure: ./stage3-deploy-resources.sh"
    log "3. 🔧 Configure kubectl access using output commands"
    log ""
    log "AWS PROFILE: $AWS_PROFILE"
    log "AWS REGION: $REGION"
    log "TERRAFORM BACKEND: $(echo "${PROJECT_ROOT}" | tr '[:upper:]' '[:lower:]')-terraform-state-${REGION}"
    log ""
    log "💡 TIP: The terraform.tfvars file is extensively documented with all options!"
    
    # Now deploy the GitOps platform using the configurations we just created
    log ""
    log "========================================="
    log "Starting Automated GitOps Deployment"
    log "========================================="
    deploy_gitops_platform
}

# Rename the function to match what main() is calling
validate_aws_credentials() {
    log "AWS profile and credentials validation..."

    # Check if AWS CLI is available
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI not installed. Please install AWS CLI to continue."
        exit 1
    fi

    # Use the SSO profile directly
    if [[ -z "${AWS_PROFILE:-}" ]]; then
        export AWS_PROFILE="akovalenko-084129280818-AdministratorAccess"
        log "Setting AWS profile to: $AWS_PROFILE"
    else
        log "Using existing AWS_PROFILE: $AWS_PROFILE"
    fi

    # Test AWS access with the profile
    log "Validating AWS access..."
    log_info "Testing with profile: $AWS_PROFILE"
    log_info "AWS CLI version: $(aws --version 2>/dev/null || echo 'AWS CLI not found')"

    # Test actual AWS API access
    log "Testing AWS API access..."
    local sts_output
    if sts_output=$(aws sts get-caller-identity --profile "$AWS_PROFILE" --region "$REGION" 2>&1); then
        # Parse JSON response more reliably
        local aws_account aws_user aws_user_id

        if command -v jq &> /dev/null; then
            aws_account=$(echo "$sts_output" | jq -r '.Account')
            aws_user=$(echo "$sts_output" | jq -r '.Arn')
            aws_user_id=$(echo "$sts_output" | jq -r '.UserId')
        else
            # Fallback parsing without jq
            aws_account=$(echo "$sts_output" | grep -o '"Account": "[^"]*"' | cut -d'"' -f4)
            aws_user=$(echo "$sts_output" | grep -o '"Arn": "[^"]*"' | cut -d'"' -f4)
            aws_user_id=$(echo "$sts_output" | grep -o '"UserId": "[^"]*"' | cut -d'"' -f4)
        fi

        log "✅ AWS access confirmed:"
        log "   Account: $aws_account"
        log "   User: $aws_user"
        log "   User ID: $aws_user_id"
        log "   Profile: $AWS_PROFILE"
        log "   Region: $REGION"

        # Save AWS profile to config file
        cat > .aws-config << EOF
export AWS_PROFILE="$AWS_PROFILE"
export AWS_DEFAULT_REGION="$REGION"
export AWS_ACCOUNT_ID="$aws_account"
export AWS_USER_ARN="$aws_user"
export AWS_USER_ID="$aws_user_id"
EOF
        log "AWS configuration saved to .aws-config"

        # Export for immediate use
        export AWS_PROFILE
        export AWS_DEFAULT_REGION="$REGION"

    else
        log_error "Failed to access AWS with profile $AWS_PROFILE"
        log_error "AWS CLI output:"
        echo "$sts_output" | while read line; do
            log_error "   $line"
        done
        log_error ""
        log_error "Since you already logged in successfully, this might be a temporary issue."
        log_error "Please try running the SSO login again:"
        log_error "   aws sso login --profile $AWS_PROFILE"
        exit 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
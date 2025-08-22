# ===================================================================
# FinPortIQ Platform - AWS Dev Environment
# ===================================================================

terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  backend "s3" {
    bucket         = "base-app-layer-terraform-state-us-east-1"
    key            = "aws/dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    use_lockfile   = true
  }
}

# ===================================================================
# Provider Configuration
# ===================================================================
provider "aws" {
  region  = var.region
  profile = var.aws_profile

  default_tags {
    tags = merge(var.common_tags, {
      Environment        = var.environment
      CloudProvider      = "aws"
      TerraformWorkspace = terraform.workspace
    })
  }
}

provider "kubernetes" {
  host                   = var.platform_cluster_enabled ? module.eks_platform_cluster[0].cluster_endpoint : ""
  cluster_ca_certificate = var.platform_cluster_enabled ? base64decode(module.eks_platform_cluster[0].cluster_certificate_authority_data) : ""
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      var.platform_cluster_enabled ? module.eks_platform_cluster[0].cluster_name : "",
      "--region",
      var.region,
      "--profile",
      var.aws_profile
    ]
  }
}

provider "helm" {
  kubernetes {
    host                   = var.platform_cluster_enabled ? module.eks_platform_cluster[0].cluster_endpoint : ""
    cluster_ca_certificate = var.platform_cluster_enabled ? base64decode(module.eks_platform_cluster[0].cluster_certificate_authority_data) : ""
    
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        var.platform_cluster_enabled ? module.eks_platform_cluster[0].cluster_name : "",
        "--region",
        var.region,
        "--profile",
        var.aws_profile
      ]
    }
  }
}

# ===================================================================
# Data Sources
# ===================================================================
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_availability_zones" "available" {
  state = "available"
}

# ===================================================================
# Local Values
# ===================================================================
locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  azs        = slice(data.aws_availability_zones.available.names, 0, var.availability_zones_count)

  cluster_name_base     = "base-app-layer-${var.environment}"
  cluster_name_platform = "platform-app-layer-${var.environment}"
}

# ===================================================================
# VPC Module
# ===================================================================
module "vpc" {
  source = "../../modules/vpc"

  project_name             = var.project_name
  environment              = var.environment
  vpc_cidr                 = var.vpc_cidr
  availability_zones       = local.azs
  private_subnets_count    = var.private_subnets_count
  public_subnets_count     = var.public_subnets_count
  database_subnets_count   = var.database_subnets_count
  
  nat_gateway_count        = var.nat_gateway_count
  enable_nat_gateway       = var.enable_nat_gateway
  single_nat_gateway       = var.single_nat_gateway
  one_nat_gateway_per_az   = var.one_nat_gateway_per_az
  
  common_tags              = var.common_tags
}

# ===================================================================
# EKS Base Cluster (Data Processing & AI)
# ===================================================================
module "eks_base_cluster" {
  count  = var.base_cluster_enabled ? 1 : 0
  source = "../../modules/eks"

  cluster_name        = local.cluster_name_base
  cluster_version     = var.base_cluster_config.version
  cluster_config      = var.base_cluster_config
  
  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets
  
  enable_irsa                = var.enable_irsa
  irsa_roles                 = var.irsa_roles
  enable_pod_identity        = var.enable_pod_identity
  pod_identity_associations  = var.pod_identity_associations
  cluster_addons             = var.cluster_addons
  
  common_tags                = var.common_tags
}

# ===================================================================
# EKS Platform Cluster (GitOps & Platform Services)
# ===================================================================
module "eks_platform_cluster" {
  count  = var.platform_cluster_enabled ? 1 : 0
  source = "../../modules/eks"

  cluster_name        = local.cluster_name_platform
  cluster_version     = var.platform_cluster_config.version
  cluster_config      = var.platform_cluster_config
  
  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets
  
  enable_irsa                = var.enable_irsa
  irsa_roles                 = var.irsa_roles
  enable_pod_identity        = var.enable_pod_identity
  pod_identity_associations  = var.pod_identity_associations
  cluster_addons             = var.cluster_addons
  
  common_tags                = var.common_tags
}

# ===================================================================
# S3 Storage for Data Lake (Optional)
# ===================================================================
module "s3_data_storage" {
  count  = var.enable_data_storage ? 1 : 0
  source = "../../modules/s3"

  project_name        = var.project_name
  environment         = var.environment
  data_storage_config = var.data_storage_config
  
  common_tags         = var.common_tags
}

# ===================================================================
# IAM Policy Attachments for Node Groups
# ===================================================================

# EBS CSI Driver policy for platform_system node group
resource "aws_iam_role_policy_attachment" "platform_system_ebs_csi" {
  count      = var.platform_cluster_enabled ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = "${local.cluster_name_platform}-platform_system-node-group-role"
  
  depends_on = [module.eks_platform_cluster]
}

# ===================================================================
# Kubernetes Storage Classes
# ===================================================================

# GP3 storage class with WaitForFirstConsumer
resource "kubernetes_storage_class" "gp3" {
  count = var.platform_cluster_enabled ? 1 : 0
  
  metadata {
    name = "gp3"
  }
  
  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
  
  parameters = {
    type   = "gp3"
    fsType = "ext4"
  }
  
  depends_on = [
    module.eks_platform_cluster,
    aws_iam_role_policy_attachment.platform_system_ebs_csi
  ]
}

# GP3 storage class with Immediate binding for Vault
resource "kubernetes_storage_class" "gp3_immediate" {
  count = var.platform_cluster_enabled ? 1 : 0
  
  metadata {
    name = "gp3-immediate" 
  }
  
  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "Immediate"
  allow_volume_expansion = true
  
  parameters = {
    type   = "gp3"
    fsType = "ext4"
  }
  
  depends_on = [
    module.eks_platform_cluster,
    aws_iam_role_policy_attachment.platform_system_ebs_csi
  ]
}

# ===================================================================
# RDS Databases (Optional)
# ===================================================================
module "rds_databases" {
  count  = var.enable_databases ? 1 : 0
  source = "../../modules/rds"

  project_name        = var.project_name
  environment         = var.environment
  vpc_id              = module.vpc.vpc_id
  database_subnets    = module.vpc.database_subnets
  database_config     = var.database_config
  
  common_tags         = var.common_tags
}

# ===================================================================
# IAM Roles for Services (Optional)
# ===================================================================
module "iam_service_roles" {
  count  = var.enable_service_iam ? 1 : 0
  source = "../../modules/iam"

  project_name        = var.project_name
  environment         = var.environment
  service_roles       = var.service_roles
  
  common_tags         = var.common_tags
}

# ===================================================================
# SSL Certificate Management (ACM)
# ===================================================================
module "acm_certificates" {
  count  = var.enable_ssl_certificates ? 1 : 0
  source = "../../modules/acm"

  project_name     = var.project_name
  environment      = var.environment
  platform_domain  = var.platform_domain
  base_domain      = var.base_domain
  
  common_tags      = var.common_tags
}

# ===================================================================
# DNS Management (Route 53)
# ===================================================================
module "route53_dns" {
  count  = var.enable_dns_management ? 1 : 0
  source = "../../modules/route53"

  project_name       = var.project_name
  environment        = var.environment
  region             = var.region
  domain_name        = var.base_domain
  platform_subdomain = var.platform_domain
  
  # ALB integration (will be populated after ALB creation)
  alb_dns_name       = var.alb_dns_name
  alb_zone_id        = var.alb_zone_id
  
  # Certificate validation records from ACM module
  certificate_validation_records = var.enable_ssl_certificates ? module.acm_certificates[0].domain_validation_options : {}
  
  enable_health_checks = var.enable_health_checks
  common_tags         = var.common_tags
  
  depends_on = [module.acm_certificates]
}

# ===================================================================
# Crossplane Infrastructure as Code Platform
# ===================================================================
module "crossplane" {
  count  = var.enable_crossplane ? 1 : 0
  source = "../../modules/crossplane"

  cluster_name           = local.cluster_name_platform
  cluster_endpoint       = var.platform_cluster_enabled ? module.eks_platform_cluster[0].cluster_endpoint : ""
  crossplane_namespace   = var.crossplane_namespace
  crossplane_version     = var.crossplane_version
  
  enable_crossplane      = var.enable_crossplane
  enable_aws_provider    = var.enable_crossplane_aws_provider
  enable_compositions    = var.enable_crossplane_compositions
  enable_metrics         = var.enable_crossplane_metrics
  
  aws_credentials_source = var.crossplane_aws_credentials_source
  create_irsa_role      = var.crossplane_create_irsa_role
  oidc_provider_arn     = var.platform_cluster_enabled ? module.eks_platform_cluster[0].oidc_provider_arn : ""
  oidc_issuer           = var.platform_cluster_enabled ? replace(module.eks_platform_cluster[0].cluster_oidc_issuer_url, "https://", "") : ""
  
  common_tags           = var.common_tags

  depends_on = [module.eks_platform_cluster]
}

# ===================================================================
# Karpenter Node Provisioning for Base Cluster
# ===================================================================
module "karpenter_base_cluster" {
  count  = var.base_cluster_enabled && var.enable_karpenter ? 1 : 0
  source = "../../modules/karpenter"

  cluster_name           = module.eks_base_cluster[0].cluster_name
  cluster_endpoint       = module.eks_base_cluster[0].cluster_endpoint
  cluster_certificate_authority_data = module.eks_base_cluster[0].cluster_certificate_authority_data
  
  enable_karpenter       = var.enable_karpenter
  karpenter_version      = var.karpenter_version
  karpenter_irsa_role_arn = lookup(module.eks_base_cluster[0].pod_identity_role_arns, "karpenter", "")
  
  vpc_id                 = module.vpc.vpc_id
  subnet_ids             = module.vpc.private_subnets
  
  common_tags            = var.common_tags

  depends_on = [
    module.eks_base_cluster,
    module.vpc
  ]
}

# ===================================================================
# Automatic Kubeconfig Updates
# ===================================================================

# Update kubeconfig for base cluster
resource "null_resource" "update_kubeconfig_base" {
  count = var.base_cluster_enabled ? 1 : 0

  triggers = {
    cluster_name = module.eks_base_cluster[0].cluster_name
    endpoint     = module.eks_base_cluster[0].cluster_endpoint
  }

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks_base_cluster[0].cluster_name} --profile ${var.aws_profile}"
  }

  depends_on = [module.eks_base_cluster]
}

# Update kubeconfig for platform cluster
resource "null_resource" "update_kubeconfig_platform" {
  count = var.platform_cluster_enabled ? 1 : 0

  triggers = {
    cluster_name = module.eks_platform_cluster[0].cluster_name
    endpoint     = module.eks_platform_cluster[0].cluster_endpoint
  }

  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks_platform_cluster[0].cluster_name} --profile ${var.aws_profile}"
  }

  depends_on = [module.eks_platform_cluster]
}
# ===================================================================
# FinPortIQ Platform - AWS Multi-Cluster Terraform Modules
# ===================================================================
# This is the root module file that orchestrates the entire platform

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
  }
}

# ===================================================================
# Provider Configuration
# ===================================================================
provider "aws" {
  region = var.region

  default_tags {
    tags = var.common_tags
  }
}

# ===================================================================
# Local Values
# ===================================================================
locals {
  cluster_name_base     = "${var.project_name}-${var.environment}-base"
  cluster_name_platform = "${var.project_name}-${var.environment}-platform"
  cluster_name_events   = "${var.project_name}-${var.environment}-events"
}

# ===================================================================
# Data Sources
# ===================================================================
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# ===================================================================
# Network Module
# ===================================================================
module "network" {
  source = "modules/network"

  project_name             = var.project_name
  environment              = var.environment
  region                   = var.region
  vpc_cidr                 = var.vpc_cidr
  availability_zones_count = var.availability_zones_count
  private_subnets_count    = var.private_subnets_count
  public_subnets_count     = var.public_subnets_count
  database_subnets_count   = var.database_subnets_count
  
  nat_gateway_count        = var.nat_gateway_count
  enable_nat_gateway       = var.enable_nat_gateway
  single_nat_gateway       = var.single_nat_gateway
  one_nat_gateway_per_az   = var.one_nat_gateway_per_az
  
  network_security_config  = var.network_security_config
  common_tags              = var.common_tags
}

# ===================================================================
# Base Cluster (Data Processing & AI)
# ===================================================================
module "base_cluster" {
  count  = var.base_cluster_enabled ? 1 : 0
  source = "modules/kubernetes"

  cluster_name         = local.cluster_name_base
  cluster_config       = var.base_cluster_config
  security_config      = var.security_config
  cluster_addons       = var.cluster_addons
  
  vpc_id               = module.network.vpc_id
  private_subnets      = module.network.private_subnets
  public_subnets       = module.network.public_subnets
  
  enable_irsa          = var.enable_irsa
  irsa_roles           = var.irsa_roles
  
  common_tags          = var.common_tags
}

# ===================================================================
# Platform Cluster (GitOps & Platform Services)
# ===================================================================
module "platform_cluster" {
  count  = var.platform_cluster_enabled ? 1 : 0
  source = "modules/kubernetes"

  cluster_name         = local.cluster_name_platform
  cluster_config       = var.platform_cluster_config
  security_config      = var.security_config
  cluster_addons       = var.cluster_addons
  
  vpc_id               = module.network.vpc_id
  private_subnets      = module.network.private_subnets
  public_subnets       = module.network.public_subnets
  
  enable_irsa          = var.enable_irsa
  irsa_roles           = var.irsa_roles
  
  common_tags          = var.common_tags
}

# ===================================================================
# Event Processing Cluster (Optional)
# ===================================================================
module "event_processing_cluster" {
  count  = var.event_processing_cluster_enabled ? 1 : 0
  source = "modules/kubernetes"

  cluster_name         = local.cluster_name_events
  cluster_config       = var.event_processing_cluster_config
  security_config      = var.security_config
  cluster_addons       = var.cluster_addons
  
  vpc_id               = module.network.vpc_id
  private_subnets      = module.network.private_subnets
  public_subnets       = module.network.public_subnets
  
  enable_irsa          = var.enable_irsa
  irsa_roles           = var.irsa_roles
  
  common_tags          = var.common_tags
}

# ===================================================================
# Storage Module (Optional)
# ===================================================================
module "storage" {
  count  = var.enable_kafka_cluster || var.enable_backup_services ? 1 : 0
  source = "modules/storage"

  project_name         = var.project_name
  environment          = var.environment
  data_storage_config  = var.data_storage_config
  backup_config        = var.backup_config
  
  common_tags          = var.common_tags
}

# ===================================================================
# Monitoring Module (Optional)
# ===================================================================
module "monitoring" {
  count  = var.enable_monitoring ? 1 : 0
  source = "modules/monitoring"

  project_name           = var.project_name
  environment            = var.environment
  observability_config   = var.observability_config
  
  common_tags            = var.common_tags
}
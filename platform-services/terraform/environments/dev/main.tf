terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "base-app-layer-terraform-state-us-east-1"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "base-app-layer-terraform-locks"
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Environment   = "dev"
      Project       = "base-app-layer"
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

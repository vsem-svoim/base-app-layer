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
  version = "~> 20.0"

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
      most_recent                 = addon_config.most_recent
      addon_version              = addon_config.addon_version != "" ? addon_config.addon_version : null
      configuration_values       = addon_config.configuration_values != "" ? addon_config.configuration_values : null
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "PRESERVE"
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
  version = "~> 20.0"

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
      most_recent                 = addon_config.most_recent
      addon_version              = addon_config.addon_version != "" ? addon_config.addon_version : null
      configuration_values       = addon_config.configuration_values != "" ? addon_config.configuration_values : null
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "PRESERVE"
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

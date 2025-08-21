# ===================================================================
# EKS Module for AWS Infrastructure
# ===================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# ===================================================================
# Data Sources
# ===================================================================
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# ===================================================================
# Local Values
# ===================================================================
locals {
  cluster_name = var.cluster_name
  partition    = data.aws_partition.current.partition
  account_id   = data.aws_caller_identity.current.account_id
  region       = data.aws_region.current.name
}

# ===================================================================
# EKS Cluster
# ===================================================================
resource "aws_eks_cluster" "main" {
  name     = local.cluster_name
  version  = var.cluster_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = ["0.0.0.0/0"]
    security_group_ids      = [aws_security_group.cluster.id]
  }

  encryption_config {
    provider {
      key_arn = aws_kms_key.eks.arn
    }
    resources = ["secrets"]
  }

  # Disable CloudWatch logging for cost optimization
  enabled_cluster_log_types = []

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSVPCResourceController,
  ]

  tags = merge(var.common_tags, {
    Name = local.cluster_name
    Type = "eks-cluster"
  })
}

# ===================================================================
# CloudWatch Log Group
# ===================================================================
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${local.cluster_name}/cluster"
  retention_in_days = 7

  tags = merge(var.common_tags, {
    Name = "${local.cluster_name}-logs"
    Type = "log-group"
  })
}

# ===================================================================
# KMS Key for EKS Encryption
# ===================================================================
resource "aws_kms_key" "eks" {
  description             = "EKS Secret Encryption Key for ${local.cluster_name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(var.common_tags, {
    Name = "${local.cluster_name}-eks-key"
    Type = "kms-key"
  })
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${local.cluster_name}-eks"
  target_key_id = aws_kms_key.eks.key_id
}

# ===================================================================
# EKS Cluster IAM Role
# ===================================================================
resource "aws_iam_role" "cluster" {
  name               = "${local.cluster_name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json

  tags = merge(var.common_tags, {
    Name = "${local.cluster_name}-cluster-role"
    Type = "iam-role"
  })
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSVPCResourceController" {
  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster.name
}

# ===================================================================
# EKS Cluster Security Group
# ===================================================================
resource "aws_security_group" "cluster" {
  name_prefix = "${local.cluster_name}-cluster-"
  description = "EKS cluster security group"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "${local.cluster_name}-cluster-sg"
    Type = "security-group"
  })
}

resource "aws_security_group_rule" "cluster_ingress_workstation_https" {
  description       = "Allow workstation to communicate with the cluster API Server"
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.cluster.id
}

# ===================================================================
# EKS Fargate Profiles
# ===================================================================
resource "aws_eks_fargate_profile" "main" {
  for_each = var.cluster_config.enable_fargate ? var.cluster_config.fargate_profiles : {}

  cluster_name           = aws_eks_cluster.main.name
  fargate_profile_name   = each.key
  pod_execution_role_arn = aws_iam_role.fargate[each.key].arn
  subnet_ids             = each.value.subnet_type == "private" ? var.subnet_ids : var.control_plane_subnet_ids

  dynamic "selector" {
    for_each = each.value.namespace_selectors
    content {
      namespace = selector.value
      labels    = each.value.label_selectors
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.fargate_AmazonEKSFargatePodExecutionRolePolicy,
  ]

  tags = merge(var.common_tags, {
    Name = "${local.cluster_name}-${each.key}-fargate"
    Type = "fargate-profile"
  })
}

# ===================================================================
# Fargate IAM Roles
# ===================================================================
resource "aws_iam_role" "fargate" {
  for_each = var.cluster_config.enable_fargate ? var.cluster_config.fargate_profiles : {}

  name = "${local.cluster_name}-${each.key}-fargate-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks-fargate-pods.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })

  tags = merge(var.common_tags, {
    Name = "${local.cluster_name}-${each.key}-fargate-role"
    Type = "iam-role"
  })
}

resource "aws_iam_role_policy_attachment" "fargate_AmazonEKSFargatePodExecutionRolePolicy" {
  for_each = var.cluster_config.enable_fargate ? var.cluster_config.fargate_profiles : {}

  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.fargate[each.key].name
}

# ===================================================================
# EKS Managed Node Groups
# ===================================================================
resource "aws_eks_node_group" "main" {
  for_each = var.cluster_config.enable_managed_nodes ? var.cluster_config.managed_node_groups : {}

  cluster_name    = aws_eks_cluster.main.name
  node_group_name = each.key
  node_role_arn   = aws_iam_role.node_group[each.key].arn
  subnet_ids      = var.subnet_ids
  instance_types  = each.value.instance_types
  capacity_type   = each.value.capacity_type
  ami_type        = each.value.ami_type
  disk_size       = each.value.disk_size

  scaling_config {
    desired_size = each.value.desired_size
    max_size     = each.value.max_size
    min_size     = each.value.min_size
  }

  update_config {
    max_unavailable_percentage = 25
  }

  labels = each.value.labels

  depends_on = [
    aws_iam_role_policy_attachment.node_group_AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.node_group_AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.node_group_AmazonEC2ContainerRegistryReadOnly,
  ]

  tags = merge(var.common_tags, {
    Name = "${local.cluster_name}-${each.key}-node-group"
    Type = "node-group"
  })
}

# ===================================================================
# Node Group IAM Roles
# ===================================================================
resource "aws_iam_role" "node_group" {
  for_each = var.cluster_config.enable_managed_nodes ? var.cluster_config.managed_node_groups : {}

  name = "${local.cluster_name}-${each.key}-node-group-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })

  tags = merge(var.common_tags, {
    Name = "${local.cluster_name}-${each.key}-node-group-role"
    Type = "iam-role"
  })
}

resource "aws_iam_role_policy_attachment" "node_group_AmazonEKSWorkerNodePolicy" {
  for_each = var.cluster_config.enable_managed_nodes ? var.cluster_config.managed_node_groups : {}

  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_group[each.key].name
}

resource "aws_iam_role_policy_attachment" "node_group_AmazonEKS_CNI_Policy" {
  for_each = var.cluster_config.enable_managed_nodes ? var.cluster_config.managed_node_groups : {}

  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_group[each.key].name
}

resource "aws_iam_role_policy_attachment" "node_group_AmazonEC2ContainerRegistryReadOnly" {
  for_each = var.cluster_config.enable_managed_nodes ? var.cluster_config.managed_node_groups : {}

  policy_arn = "arn:${local.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_group[each.key].name
}

# ===================================================================
# EKS Addons
# ===================================================================
resource "aws_eks_addon" "main" {
  for_each = var.cluster_addons

  cluster_name             = aws_eks_cluster.main.name
  addon_name               = each.key
  addon_version            = each.value.addon_version != "" ? each.value.addon_version : null
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"
  configuration_values     = each.value.configuration_values != "" ? each.value.configuration_values : null

  depends_on = [
    aws_eks_node_group.main,
    aws_eks_fargate_profile.main,
  ]

  tags = merge(var.common_tags, {
    Name = "${local.cluster_name}-${each.key}-addon"
    Type = "eks-addon"
  })
}

# ===================================================================
# IRSA (IAM Roles for Service Accounts)
# ===================================================================
data "tls_certificate" "cluster" {
  count = var.enable_irsa ? 1 : 0
  url   = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  count = var.enable_irsa ? 1 : 0

  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster[0].certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = merge(var.common_tags, {
    Name = "${local.cluster_name}-irsa-oidc"
    Type = "oidc-provider"
  })
}

# IRSA Roles
resource "aws_iam_role" "irsa" {
  for_each = var.enable_irsa ? var.irsa_roles : {}

  name = "${substr("${local.cluster_name}-${each.key}", 0, 59)}-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = var.enable_irsa ? aws_iam_openid_connect_provider.cluster[0].arn : ""
        }
        Condition = {
          StringEquals = {
            "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:sub" = flatten([
              for sa in each.value.service_accounts : [
                for ns in each.value.namespaces : 
                "system:serviceaccount:${ns}:${sa}"
              ]
            ])
            "${replace(aws_eks_cluster.main.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${substr("${local.cluster_name}-${each.key}", 0, 59)}-irsa"
    Type = "iam-role"
  })
}

resource "aws_iam_role_policy_attachment" "irsa" {
  for_each = var.enable_irsa ? {
    for pair in flatten([
      for role_name, role_config in var.irsa_roles : [
        for policy_arn in role_config.policy_arns : {
          role_name   = role_name
          policy_arn  = policy_arn
        }
      ]
    ]) : "${pair.role_name}-${replace(pair.policy_arn, "/[^a-zA-Z0-9]/", "-")}" => pair
  } : {}

  role       = aws_iam_role.irsa[each.value.role_name].name
  policy_arn = each.value.policy_arn
}
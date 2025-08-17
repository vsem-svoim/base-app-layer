# ===================================================================
# Модуль многокластерной инфраструктуры Kubernetes
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
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# Источники данных
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# Локальные переменные для оптимизации
locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.availability_zones_count)

  # Динамический расчёт CIDR подсетей
  private_subnet_cidrs = [
    for i in range(var.availability_zones_count * var.private_subnets_count) :
    cidrsubnet(var.vpc_cidr, 8, i)
  ]

  public_subnet_cidrs = [
    for i in range(var.availability_zones_count * var.public_subnets_count) :
    cidrsubnet(var.vpc_cidr, 8, i + (var.availability_zones_count * var.private_subnets_count))
  ]

  database_subnet_cidrs = [
    for i in range(var.availability_zones_count * var.database_subnets_count) :
    cidrsubnet(var.vpc_cidr, 8, i + (var.availability_zones_count * (var.private_subnets_count + var.public_subnets_count)))
  ]

  # Имена кластеров
  base_cluster_name              = var.base_cluster_enabled ? "${var.project_name}-${var.base_cluster_config.name}-${var.environment}" : ""
  platform_cluster_name         = var.platform_cluster_enabled ? "${var.project_name}-${var.platform_cluster_config.name}-${var.environment}" : ""
  event_processing_cluster_name  = var.event_processing_cluster_enabled ? "${var.project_name}-${var.event_processing_cluster_config.name}-${var.environment}" : ""

  # Таги для обнаружения кластеров
  cluster_tags = merge(
    var.base_cluster_enabled ? {
      "kubernetes.io/cluster/${local.base_cluster_name}" = "shared"
    } : {},
    var.platform_cluster_enabled ? {
      "kubernetes.io/cluster/${local.platform_cluster_name}" = "shared"
    } : {},
    var.event_processing_cluster_enabled ? {
      "kubernetes.io/cluster/${local.event_processing_cluster_name}" = "shared"
    } : {}
  )
}

# ===================================================================
# KMS ключ для шифрования кластеров
# ===================================================================

resource "aws_kms_key" "cluster_encryption" {
  count = var.security_config.enable_secrets_encryption ? 1 : 0

  description             = "KMS key for EKS cluster encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = var.security_config.kms_key_rotation_enabled

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableClusterEncryption"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Purpose = "cluster-encryption"
  })
}

resource "aws_kms_alias" "cluster_encryption" {
  count         = var.security_config.enable_secrets_encryption ? 1 : 0
  name          = "alias/${var.project_name}-cluster-encryption"
  target_key_id = aws_kms_key.cluster_encryption[0].key_id
}

# ===================================================================
# Общая VPC для всех кластеров
# ===================================================================

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  azs              = local.azs
  private_subnets  = local.private_subnet_cidrs
  public_subnets   = local.public_subnet_cidrs
  database_subnets = local.database_subnet_cidrs

  # Конфигурация NAT Gateway для HA
  enable_nat_gateway     = var.enable_nat_gateway
  single_nat_gateway     = var.single_nat_gateway
  one_nat_gateway_per_az = var.one_nat_gateway_per_az

  # Расширенные возможности VPC
  enable_vpn_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true
  enable_flow_log      = true
  flow_log_destination_type = "s3"
  flow_log_destination_arn  = aws_s3_bucket.vpc_flow_logs.arn

  # Подсети базы данных
  create_database_subnet_group       = true
  create_database_subnet_route_table = true

  # Таги для всех подсетей
  tags = merge(var.tags, local.cluster_tags)

  # Таги для публичных подсетей (для load balancer)
  public_subnet_tags = merge(local.cluster_tags, {
    "kubernetes.io/role/elb" = "1"
    "SubnetType"             = "public"
  })

  # Таги для приватных подсетей (для internal load balancer)
  private_subnet_tags = merge(local.cluster_tags, {
    "kubernetes.io/role/internal-elb" = "1"
    "SubnetType"                      = "private"
  })

  # Таги для подсетей БД
  database_subnet_tags = {
    "SubnetType" = "database"
  }
}

# S3 bucket для VPC Flow Logs
resource "aws_s3_bucket" "vpc_flow_logs" {
  bucket = "${var.project_name}-vpc-flow-logs-${var.environment}"

  tags = merge(var.tags, {
    Purpose = "vpc-flow-logs"
  })
}

resource "aws_s3_bucket_server_side_encryption_configuration" "vpc_flow_logs" {
  bucket = aws_s3_bucket.vpc_flow_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "vpc_flow_logs" {
  bucket = aws_s3_bucket.vpc_flow_logs.id

  rule {
    id     = "flow_logs_lifecycle"
    status = "Enabled"

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# ===================================================================
# VPC Endpoints для безопасности
# ===================================================================

resource "aws_vpc_endpoint" "this" {
  for_each = toset(var.network_security_config.vpc_endpoints)

  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]

  private_dns_enabled = true

  tags = merge(var.tags, {
    Name    = "${var.project_name}-${each.value}-endpoint"
    Purpose = "service-endpoint"
  })
}

resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "${var.project_name}-vpc-endpoints"
  vpc_id      = module.vpc.vpc_id
  description = "Security group for VPC endpoints"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.tags, {
    Name    = "${var.project_name}-vpc-endpoints-sg"
    Purpose = "vpc-endpoints"
  })
}

# ===================================================================
# Базовый кластер (для данных и AI)
# ===================================================================

module "base_layer_eks" {
  count = var.base_cluster_enabled ? 1 : 0

  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = local.base_cluster_name
  cluster_version = var.base_cluster_config.version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Конфигурация доступа к API
  cluster_endpoint_private_access      = lookup(var.base_cluster_config.endpoint_config, "private_access", true)
  cluster_endpoint_public_access       = lookup(var.base_cluster_config.endpoint_config, "public_access", true)
  cluster_endpoint_public_access_cidrs = lookup(var.base_cluster_config.endpoint_config, "public_access_cidrs", ["0.0.0.0/0"])

  # Логирование кластера
  cluster_enabled_log_types = var.base_cluster_config.enabled_cluster_log_types

  # Шифрование секретов
  cluster_encryption_config = var.security_config.enable_secrets_encryption ? [
    {
      provider_key_arn = aws_kms_key.cluster_encryption[0].arn
      resources        = ["secrets"]
    }
  ] : []

  # Управляемые группы узлов
  eks_managed_node_groups = var.base_cluster_config.enable_managed_nodes ? {
    for name, config in var.base_cluster_config.managed_node_groups : name => {
      name = "${var.project_name}-${name}"

      instance_types = config.instance_types
      capacity_type  = config.capacity_type

      min_size     = config.min_size
      max_size     = config.max_size
      desired_size = config.desired_size

      # Расширенная конфигурация дисков
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = config.disk_size
            volume_type          = config.disk_type
            iops                 = config.disk_type == "gp3" ? 3000 : null
            throughput           = config.disk_type == "gp3" ? 125 : null
            encrypted            = true
            delete_on_termination = true
          }
        }
      }

      ami_type = config.ami_type
      labels   = config.labels

      taints = lookup(config, "taints", {}) != {} ? [
        for taint_name, taint_config in config.taints : {
          key    = taint_config.key
          value  = taint_config.value
          effect = taint_config.effect
        }
      ] : []

      # Смешанная политика экземпляров для оптимизации затрат
      use_mixed_instances_policy = lookup(config, "mixed_instances_policy", null) != null
      mixed_instances_policy = lookup(config, "mixed_instances_policy", null)

      # Расширенная конфигурация масштабирования
      scaling_config = lookup(config, "scaling_config", null) != null ? config.scaling_config : {
        desired_size = config.desired_size
        max_size     = config.max_size
        min_size     = config.min_size
      }

      # Обновления узлов
      update_config = {
        max_unavailable_percentage = 25
      }

      tags = merge(var.tags, {
        ClusterType = "base-layer"
        NodeGroup   = name
      })
    }
  } : {}

  # Профили Fargate
  fargate_profiles = var.base_cluster_config.enable_fargate ? {
    for name, config in var.base_cluster_config.fargate_profiles : name => {
      name = "${var.project_name}-base-${name}"
      selectors = [
        for ns in config.namespace_selectors : {
          namespace = ns
          labels    = lookup(config, "label_selectors", {})
        }
      ]

      subnet_ids = lookup(config, "subnet_type", "private") == "private" ? module.vpc.private_subnets : module.vpc.public_subnets
    }
  } : {}

  # Аддоны кластера
  cluster_addons = {
    for addon_name, addon_config in var.cluster_addons : addon_name => {
      most_recent                = addon_config.most_recent
      addon_version             = addon_config.addon_version != "" ? addon_config.addon_version : null
      configuration_values      = addon_config.configuration_values != "" ? addon_config.configuration_values : null
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }
  }

  tags = merge(var.tags, {
    ClusterType = "base-layer"
    Purpose     = "data-ai-processing"
  })

  depends_on = [module.vpc]
}

# ===================================================================
# Кластер платформенных сервисов
# ===================================================================

module "platform_services_eks" {
  count = var.platform_cluster_enabled ? 1 : 0

  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = local.platform_cluster_name
  cluster_version = var.platform_cluster_config.version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Конфигурация доступа к API
  cluster_endpoint_private_access      = lookup(var.platform_cluster_config.endpoint_config, "private_access", true)
  cluster_endpoint_public_access       = lookup(var.platform_cluster_config.endpoint_config, "public_access", true)
  cluster_endpoint_public_access_cidrs = lookup(var.platform_cluster_config.endpoint_config, "public_access_cidrs", ["0.0.0.0/0"])

  # Логирование кластера
  cluster_enabled_log_types = var.platform_cluster_config.enabled_cluster_log_types

  # Шифрование секретов
  cluster_encryption_config = var.security_config.enable_secrets_encryption ? [
    {
      provider_key_arn = aws_kms_key.cluster_encryption[0].arn
      resources        = ["secrets"]
    }
  ] : []

  # Управляемые группы узлов
  eks_managed_node_groups = var.platform_cluster_config.enable_managed_nodes ? {
    for name, config in var.platform_cluster_config.managed_node_groups : name => {
      name = "${var.project_name}-${name}"

      instance_types = config.instance_types
      capacity_type  = config.capacity_type

      min_size     = config.min_size
      max_size     = config.max_size
      desired_size = config.desired_size

      # Расширенная конфигурация дисков
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = config.disk_size
            volume_type          = config.disk_type
            iops                 = config.disk_type == "gp3" ? 3000 : null
            throughput           = config.disk_type == "gp3" ? 125 : null
            encrypted            = true
            delete_on_termination = true
          }
        }
      }

      ami_type = config.ami_type
      labels   = config.labels

      taints = lookup(config, "taints", {}) != {} ? [
        for taint_name, taint_config in config.taints : {
          key    = taint_config.key
          value  = taint_config.value
          effect = taint_config.effect
        }
      ] : []

      # Смешанная политика экземпляров
      use_mixed_instances_policy = lookup(config, "mixed_instances_policy", null) != null
      mixed_instances_policy = lookup(config, "mixed_instances_policy", null)

      # Обновления узлов
      update_config = {
        max_unavailable_percentage = 25
      }

      tags = merge(var.tags, {
        ClusterType = "platform-services"
        NodeGroup   = name
      })
    }
  } : {}

  # Профили Fargate
  fargate_profiles = var.platform_cluster_config.enable_fargate ? {
    for name, config in var.platform_cluster_config.fargate_profiles : name => {
      name = "${var.project_name}-platform-${name}"
      selectors = [
        for ns in config.namespace_selectors : {
          namespace = ns
          labels    = lookup(config, "label_selectors", {})
        }
      ]

      subnet_ids = lookup(config, "subnet_type", "private") == "private" ? module.vpc.private_subnets : module.vpc.public_subnets
    }
  } : {}

  # Аддоны кластера
  cluster_addons = {
    for addon_name, addon_config in var.cluster_addons : addon_name => {
      most_recent                = addon_config.most_recent
      addon_version             = addon_config.addon_version != "" ? addon_config.addon_version : null
      configuration_values      = addon_config.configuration_values != "" ? addon_config.configuration_values : null
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }
  }

  tags = merge(var.tags, {
    ClusterType = "platform-services"
    Purpose     = "gitops-monitoring-ml"
  })

  depends_on = [module.vpc]
}

# ===================================================================
# Кластер обработки событий
# ===================================================================

module "event_processing_eks" {
  count = var.event_processing_cluster_enabled ? 1 : 0

  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = local.event_processing_cluster_name
  cluster_version = var.event_processing_cluster_config.version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Приватный кластер для безопасности
  cluster_endpoint_private_access      = lookup(var.event_processing_cluster_config.endpoint_config, "private_access", true)
  cluster_endpoint_public_access       = lookup(var.event_processing_cluster_config.endpoint_config, "public_access", false)
  cluster_endpoint_public_access_cidrs = lookup(var.event_processing_cluster_config.endpoint_config, "public_access_cidrs", [])

  # Логирование кластера
  cluster_enabled_log_types = var.event_processing_cluster_config.enabled_cluster_log_types

  # Шифрование секретов
  cluster_encryption_config = var.security_config.enable_secrets_encryption ? [
    {
      provider_key_arn = aws_kms_key.cluster_encryption[0].arn
      resources        = ["secrets"]
    }
  ] : []

  # Управляемые группы узлов (только узлы, без Fargate)
  eks_managed_node_groups = var.event_processing_cluster_config.enable_managed_nodes ? {
    for name, config in var.event_processing_cluster_config.managed_node_groups : name => {
      name = "${var.project_name}-${name}"

      instance_types = config.instance_types
      capacity_type  = config.capacity_type

      min_size     = config.min_size
      max_size     = config.max_size
      desired_size = config.desired_size

      # Оптимизированная конфигурация дисков для событий
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = config.disk_size
            volume_type          = config.disk_type
            iops                 = config.disk_type == "gp3" ? 16000 : null  # Высокий IOPS для событий
            throughput           = config.disk_type == "gp3" ? 1000 : null   # Высокая пропускная способность
            encrypted            = true
            delete_on_termination = true
          }
        }
      }

      ami_type = config.ami_type
      labels   = config.labels

      taints = lookup(config, "taints", {}) != {} ? [
        for taint_name, taint_config in config.taints : {
          key    = taint_config.key
          value  = taint_config.value
          effect = taint_config.effect
        }
      ] : []

      # Обновления узлов с минимальным downtime
      update_config = {
        max_unavailable = 1
      }

      tags = merge(var.tags, {
        ClusterType = "event-processing"
        NodeGroup   = name
      })
    }
  } : {}

  tags = merge(var.tags, {
    ClusterType = "event-processing"
    Purpose     = "kafka-streaming"
  })

  depends_on = [module.vpc]
}

# ===================================================================
# IRSA роли
# ===================================================================

module "irsa_roles" {
  for_each = var.enable_irsa ? var.irsa_roles : {}

  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.project_name}-${each.key}-role"

  role_policy_arns = {
    for i, arn in each.value.policy_arns : "policy_${i}" => arn
  }

  # Конфигурация OIDC провайдеров для всех активных кластеров
  oidc_providers = merge(
    var.platform_cluster_enabled ? {
      platform = {
        provider_arn = module.platform_services_eks[0].oidc_provider_arn
        namespace_service_accounts = flatten([
          for ns in each.value.namespaces : [
            for sa in each.value.service_accounts : "${ns}:${sa}"
          ]
        ])
      }
    } : {},
    var.base_cluster_enabled ? {
      base = {
        provider_arn = module.base_layer_eks[0].oidc_provider_arn
        namespace_service_accounts = flatten([
          for ns in each.value.namespaces : [
            for sa in each.value.service_accounts : "${ns}:${sa}"
          ]
        ])
      }
    } : {},
    var.event_processing_cluster_enabled ? {
      events = {
        provider_arn = module.event_processing_eks[0].oidc_provider_arn
        namespace_service_accounts = flatten([
          for ns in each.value.namespaces : [
            for sa in each.value.service_accounts : "${ns}:${sa}"
          ]
        ])
      }
    } : {}
  )

  tags = merge(var.tags, {
    Role    = each.key
    Purpose = "service-account-role"
  })
}
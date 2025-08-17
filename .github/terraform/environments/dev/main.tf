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
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "base-app-layer-terraform-locks"
  }
}

# Получение текущего контекста AWS
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Генерация случайного ID для уникальности ресурсов
resource "random_string" "resource_suffix" {
  length  = 8
  special = false
  upper   = false
}

provider "aws" {
  region  = var.region
  profile = "akovalenko-084129280818-AdministratorAccess"

  default_tags {
    tags = merge(var.common_tags, {
      TerraformWorkspace = terraform.workspace
      DeploymentId       = random_string.resource_suffix.result
    })
  }
}

# Локальные переменные для оптимизации
locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  # Конфигурация бэкендов для событийной архитектуры
  event_storage_config = merge(var.data_storage_config, {
    kinesis_streams = {
      data_events = {
        shard_count      = 3
        retention_period = 168 # 7 дней
      }
      user_events = {
        shard_count      = 2
        retention_period = 24
      }
    }
  })
}

# Основной модуль многокластерной инфраструктуры
module "multi_cluster_eks" {
  source = "../../modules/kubernetes"

  # Базовая конфигурация
  project_name = var.project_name
  environment  = var.environment
  region       = var.region
  account_id   = local.account_id

  # Конфигурация VPC с улучшенной безопасностью
  vpc_cidr                 = var.vpc_cidr
  availability_zones_count = var.availability_zones_count
  private_subnets_count    = var.private_subnets_count
  public_subnets_count     = var.public_subnets_count
  database_subnets_count   = var.database_subnets_count

  # Конфигурация NAT для высокой доступности
  nat_gateway_count      = var.nat_gateway_count
  enable_nat_gateway     = var.enable_nat_gateway
  single_nat_gateway     = var.single_nat_gateway
  one_nat_gateway_per_az = var.one_nat_gateway_per_az

  # Расширенная конфигурация безопасности
  security_config         = var.security_config
  network_security_config = var.network_security_config

  # Конфигурация кластеров
  base_cluster_enabled             = var.base_cluster_enabled
  platform_cluster_enabled        = var.platform_cluster_enabled
  event_processing_cluster_enabled = var.event_processing_cluster_enabled

  base_cluster_config             = var.base_cluster_config
  platform_cluster_config        = var.platform_cluster_config
  event_processing_cluster_config = var.event_processing_cluster_config

  # Аддоны и IRSA с минимальными привилегиями
  cluster_addons = var.cluster_addons
  enable_irsa    = var.enable_irsa
  irsa_roles     = var.irsa_roles

  # Конфигурация хранения данных для микросервисов
  data_storage_config = local.event_storage_config

  # Конфигурация наблюдаемости
  observability_config = var.observability_config

  # Резервное копирование и аварийное восстановление
  backup_config = var.backup_config

  tags = var.common_tags

  depends_on = [random_string.resource_suffix]
}

# Kinesis для событийной архитектуры
resource "aws_kinesis_stream" "event_streams" {
  for_each = local.event_storage_config.kinesis_streams

  name             = "${var.project_name}-${each.key}-stream"
  shard_count      = each.value.shard_count
  retention_period = each.value.retention_period

  # Шифрование событий
  encryption_type = "KMS"
  kms_key_id      = aws_kms_key.events_key.arn

  tags = merge(var.common_tags, {
    Purpose = "event-streaming"
    StreamType = each.key
  })
}

# KMS ключ для шифрования событий
resource "aws_kms_key" "events_key" {
  description             = "KMS key for event encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableEventProcessing"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })

  tags = merge(var.common_tags, {
    Purpose = "event-encryption"
  })
}

resource "aws_kms_alias" "events_key_alias" {
  name          = "alias/${var.project_name}-events-key"
  target_key_id = aws_kms_key.events_key.key_id
}

# EventBridge для интеграции микросервисов
resource "aws_cloudwatch_event_bus" "microservices_bus" {
  name = "${var.project_name}-microservices-bus"

  tags = merge(var.common_tags, {
    Purpose = "microservices-integration"
  })
}

# SQS для надежной доставки сообщений
resource "aws_sqs_queue" "dlq" {
  name                      = "${var.project_name}-dlq"
  message_retention_seconds = 1209600 # 14 дней

  # Шифрование очереди
  kms_master_key_id                 = aws_kms_key.events_key.arn
  kms_data_key_reuse_period_seconds = 300

  tags = merge(var.common_tags, {
    Purpose = "dead-letter-queue"
  })
}

# CloudWatch Log Groups для централизованного логирования
resource "aws_cloudwatch_log_group" "microservices_logs" {
  name              = "/aws/microservices/${var.project_name}"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.events_key.arn

  tags = merge(var.common_tags, {
    Purpose = "microservices-logging"
  })
}

# Конфигурация для Helm провайдера (когда кластеры готовы)
data "aws_eks_cluster" "platform_cluster" {
  count = var.platform_cluster_enabled ? 1 : 0
  name  = module.multi_cluster_eks.platform_cluster_name

  depends_on = [module.multi_cluster_eks]
}

data "aws_eks_cluster_auth" "platform_cluster" {
  count = var.platform_cluster_enabled ? 1 : 0
  name  = module.multi_cluster_eks.platform_cluster_name

  depends_on = [module.multi_cluster_eks]
}

# Провайдеры для Kubernetes и Helm (для платформенного кластера)
provider "kubernetes" {
  alias = "platform"

  host                   = var.platform_cluster_enabled ? data.aws_eks_cluster.platform_cluster[0].endpoint : ""
  cluster_ca_certificate = var.platform_cluster_enabled ? base64decode(data.aws_eks_cluster.platform_cluster[0].certificate_authority[0].data) : ""
  token                  = var.platform_cluster_enabled ? data.aws_eks_cluster_auth.platform_cluster[0].token : ""
}

provider "helm" {
  alias = "platform"

  kubernetes {
    host                   = var.platform_cluster_enabled ? data.aws_eks_cluster.platform_cluster[0].endpoint : ""
    cluster_ca_certificate = var.platform_cluster_enabled ? base64decode(data.aws_eks_cluster.platform_cluster[0].certificate_authority[0].data) : ""
    token                  = var.platform_cluster_enabled ? data.aws_eks_cluster_auth.platform_cluster[0].token : ""
  }
}
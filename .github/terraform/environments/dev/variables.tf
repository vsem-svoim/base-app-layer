# ===================================================================
# Базовые переменные конфигурации
# ===================================================================

variable "project_name" {
  description = "Имя проекта для именования ресурсов"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Имя проекта должно содержать только строчные буквы, цифры и дефисы."
  }
}

variable "environment" {
  description = "Окружение (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Окружение должно быть: dev, staging или prod."
  }
}

variable "region" {
  description = "AWS регион"
  type        = string
  default     = "us-east-1"
}

# ===================================================================
# Конфигурация опциональных сервисов
# ===================================================================

variable "enable_base_data_ingestion" {
  description = "Включить базовые компоненты обработки данных"
  type        = bool
  default     = true
}

variable "enable_argocd" {
  description = "Включить ArgoCD для GitOps"
  type        = bool
  default     = true
}

variable "enable_airflow" {
  description = "Включить Apache Airflow для оркестрации"
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Включить стек мониторинга (Prometheus, Grafana)"
  type        = bool
  default     = true
}

variable "enable_ml_platform" {
  description = "Включить ML платформу (MLflow, Kubeflow)"
  type        = bool
  default     = true
}

variable "enable_kafka_cluster" {
  description = "Включить Kafka кластер для событий"
  type        = bool
  default     = false
}

variable "enable_event_processing" {
  description = "Включить обработку событий и потоков"
  type        = bool
  default     = false
}

variable "enable_istio_service_mesh" {
  description = "Включить Istio service mesh"
  type        = bool
  default     = false
}

variable "enable_backup_services" {
  description = "Включить сервисы резервного копирования"
  type        = bool
  default     = false
}

variable "enable_gpu_workloads" {
  description = "Включить GPU узлы для ML задач"
  type        = bool
  default     = false
}

variable "enable_big_data_processing" {
  description = "Включить узлы для обработки больших данных"
  type        = bool
  default     = false
}

# ===================================================================
# Конфигурация VPC для микросервисов
# ===================================================================

variable "vpc_cidr" {
  description = "CIDR блок для VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "CIDR блок должен быть валидным."
  }
}

variable "availability_zones_count" {
  description = "Количество зон доступности"
  type        = number
  default     = 3

  validation {
    condition     = var.availability_zones_count >= 2 && var.availability_zones_count <= 6
    error_message = "Количество AZ должно быть от 2 до 6."
  }
}

variable "private_subnets_count" {
  description = "Количество приватных подсетей на AZ"
  type        = number
  default     = 2
}

variable "public_subnets_count" {
  description = "Количество публичных подсетей на AZ"
  type        = number
  default     = 1
}

variable "database_subnets_count" {
  description = "Количество подсетей БД на AZ"
  type        = number
  default     = 1
}

# ===================================================================
# Конфигурация NAT Gateway
# ===================================================================

variable "nat_gateway_count" {
  description = "Количество NAT Gateway"
  type        = number
  default     = 3
}

variable "enable_nat_gateway" {
  description = "Включить NAT Gateway"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Использовать один NAT для всех приватных подсетей"
  type        = bool
  default     = false
}

variable "one_nat_gateway_per_az" {
  description = "Один NAT Gateway на зону доступности"
  type        = bool
  default     = true
}

# ===================================================================
# Расширенная конфигурация безопасности
# ===================================================================

variable "security_config" {
  description = "Конфигурация безопасности кластеров"
  type = object({
    enable_pod_security_standards = optional(bool, true)
    pod_security_standard          = optional(string, "restricted")
    enable_secrets_encryption      = optional(bool, true)
    kms_key_rotation_enabled      = optional(bool, true)
    enable_audit_logging          = optional(bool, true)
    audit_log_retention_days      = optional(number, 90)
  })
  default = {
    enable_pod_security_standards = true
    pod_security_standard          = "restricted"
    enable_secrets_encryption      = true
    kms_key_rotation_enabled      = true
    enable_audit_logging          = true
    audit_log_retention_days      = 90
  }
}

variable "network_security_config" {
  description = "Конфигурация сетевой безопасности"
  type = object({
    waf_enabled                           = optional(bool, true)
    enable_microservice_security_groups   = optional(bool, true)
    enable_network_policies               = optional(bool, true)
    vpc_endpoints                         = optional(list(string), ["s3", "ecr.api", "ecr.dkr", "logs"])
  })
  default = {
    waf_enabled                           = true
    enable_microservice_security_groups   = true
    enable_network_policies               = true
    vpc_endpoints                         = ["s3", "ecr.api", "ecr.dkr", "logs", "monitoring", "events"]
  }
}

# ===================================================================
# Конфигурация кластеров
# ===================================================================

variable "base_cluster_enabled" {
  description = "Включить базовый кластер"
  type        = bool
  default     = true
}

variable "platform_cluster_enabled" {
  description = "Включить кластер платформенных сервисов"
  type        = bool
  default     = true
}

variable "event_processing_cluster_enabled" {
  description = "Включить кластер обработки событий"
  type        = bool
  default     = true
}

variable "base_cluster_config" {
  description = "Конфигурация базового кластера для данных и AI"
  type = object({
    name               = string
    version            = string
    enable_fargate     = optional(bool, true)
    enable_managed_nodes = optional(bool, true)

    endpoint_config = optional(object({
      private_access      = optional(bool, true)
      public_access       = optional(bool, true)
      public_access_cidrs = optional(list(string), ["0.0.0.0/0"])
    }), {})

    enabled_cluster_log_types = optional(list(string), ["api", "audit", "authenticator"])

    fargate_profiles = optional(map(object({
      namespace_selectors = list(string)
      label_selectors    = optional(map(string), {})
      subnet_type        = optional(string, "private")
    })), {})

    managed_node_groups = optional(map(object({
      instance_types = list(string)
      capacity_type  = optional(string, "ON_DEMAND")
      min_size      = optional(number, 0)
      max_size      = optional(number, 10)
      desired_size  = optional(number, 1)
      disk_size     = optional(number, 100)
      disk_type     = optional(string, "gp3")
      ami_type      = optional(string, "BOTTLEROCKET_x86_64")
      labels        = optional(map(string), {})
      taints = optional(map(object({
        key    = string
        value  = string
        effect = string
      })), {})

      mixed_instances_policy = optional(object({
        instances_distribution = optional(object({
          on_demand_percentage     = optional(number, 20)
          spot_allocation_strategy = optional(string, "price-capacity-optimized")
          spot_instance_pools      = optional(number, 3)
        }), {})
      }), null)

      scaling_config = optional(object({
        desired_size = number
        max_size     = number
        min_size     = number
      }), null)
    })), {})
  })
}

variable "platform_cluster_config" {
  description = "Конфигурация кластера платформенных сервисов"
  type = object({
    name               = string
    version            = string
    enable_fargate     = optional(bool, true)
    enable_managed_nodes = optional(bool, true)

    endpoint_config = optional(object({
      private_access      = optional(bool, true)
      public_access       = optional(bool, true)
      public_access_cidrs = optional(list(string), ["0.0.0.0/0"])
    }), {})

    enabled_cluster_log_types = optional(list(string), ["api", "audit"])

    fargate_profiles = optional(map(object({
      namespace_selectors = list(string)
      label_selectors    = optional(map(string), {})
      subnet_type        = optional(string, "private")
    })), {})

    managed_node_groups = optional(map(object({
      instance_types = list(string)
      capacity_type  = optional(string, "MIXED")
      min_size      = optional(number, 1)
      max_size      = optional(number, 15)
      desired_size  = optional(number, 3)
      disk_size     = optional(number, 200)
      disk_type     = optional(string, "gp3")
      ami_type      = optional(string, "BOTTLEROCKET_x86_64")
      labels        = optional(map(string), {})
      taints = optional(map(object({
        key    = string
        value  = string
        effect = string
      })), {})

      mixed_instances_policy = optional(object({
        instances_distribution = optional(object({
          on_demand_percentage     = optional(number, 40)
          spot_allocation_strategy = optional(string, "price-capacity-optimized")
        }), {})
      }), null)
    })), {})
  })
}

variable "event_processing_cluster_config" {
  description = "Конфигурация кластера обработки событий"
  type = object({
    name               = string
    version            = string
    enable_fargate     = optional(bool, false)
    enable_managed_nodes = optional(bool, true)

    endpoint_config = optional(object({
      private_access      = optional(bool, true)
      public_access       = optional(bool, false)
      public_access_cidrs = optional(list(string), [])
    }), {})

    enabled_cluster_log_types = optional(list(string), ["api", "audit"])

    managed_node_groups = optional(map(object({
      instance_types = list(string)
      capacity_type  = optional(string, "ON_DEMAND")
      min_size      = optional(number, 1)
      max_size      = optional(number, 50)
      desired_size  = optional(number, 3)
      disk_size     = optional(number, 200)
      disk_type     = optional(string, "gp3")
      ami_type      = optional(string, "BOTTLEROCKET_x86_64")
      labels        = optional(map(string), {})
      taints = optional(map(object({
        key    = string
        value  = string
        effect = string
      })), {})
    })), {})
  })
}

# ===================================================================
# Аддоны EKS
# ===================================================================

variable "cluster_addons" {
  description = "Конфигурация аддонов EKS"
  type = map(object({
    most_recent           = optional(bool, true)
    addon_version        = optional(string, "")
    configuration_values = optional(string, "")
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
      most_recent           = true
      addon_version        = ""
      configuration_values = ""
    }
    aws-ebs-csi-driver = {
      most_recent           = true
      addon_version        = ""
      configuration_values = ""
    }
    aws-efs-csi-driver = {
      most_recent           = true
      addon_version        = ""
      configuration_values = ""
    }
  }
}

# ===================================================================
# IRSA роли с минимальными привилегиями
# ===================================================================

variable "enable_irsa" {
  description = "Включить IAM роли для сервисных аккаунтов"
  type        = bool
  default     = true
}

variable "irsa_roles" {
  description = "Конфигурация IRSA ролей"
  type = map(object({
    policy_arns      = list(string)
    namespaces       = list(string)
    service_accounts = list(string)
  }))
  default = {}
}

# ===================================================================
# Конфигурация хранения данных для событийной архитектуры
# ===================================================================

variable "data_storage_config" {
  description = "Конфигурация хранения данных"
  type = object({
    s3_buckets = optional(map(object({
      name                    = string
      versioning             = optional(bool, true)
      lifecycle_rules        = optional(bool, true)
      glacier_transition_days = optional(number, 30)
    })), {})

    msk_config = optional(object({
      kafka_version         = optional(string, "3.6.0")
      instance_type        = optional(string, "kafka.m7g.large")
      ebs_volume_size      = optional(number, 1000)
      auto_scaling_enabled = optional(bool, true)
    }), {})

    elasticache_config = optional(object({
      node_type                   = optional(string, "cache.r7g.large")
      num_cache_nodes            = optional(number, 3)
      automatic_failover_enabled = optional(bool, true)
    }), {})
  })
  default = {}
}

# ===================================================================
# Конфигурация наблюдаемости
# ===================================================================

variable "observability_config" {
  description = "Конфигурация наблюдаемости и мониторинга"
  type = object({
    amp_enabled              = optional(bool, true)
    amp_workspace_name       = optional(string, "finportiq-prometheus")
    amg_enabled              = optional(bool, true)
    amg_workspace_name       = optional(string, "finportiq-grafana")
    otel_enabled             = optional(bool, true)
    xray_enabled             = optional(bool, true)
    container_insights_enabled = optional(bool, true)
  })
  default = {
    amp_enabled              = true
    amp_workspace_name       = "prometheus-workspace"
    amg_enabled              = true
    amg_workspace_name       = "grafana-workspace"
    otel_enabled             = true
    xray_enabled             = true
    container_insights_enabled = true
  }
}

# ===================================================================
# Конфигурация резервного копирования
# ===================================================================

variable "backup_config" {
  description = "Конфигурация резервного копирования"
  type = object({
    ebs_backup_enabled         = optional(bool, true)
    ebs_backup_retention_days  = optional(number, 30)
    velero_enabled             = optional(bool, true)
    velero_backup_location     = optional(string, "s3")
    velero_backup_retention    = optional(string, "720h")
    enable_cross_region_backup = optional(bool, true)
    backup_region              = optional(string, "us-west-2")
  })
  default = {
    ebs_backup_enabled         = true
    ebs_backup_retention_days  = 30
    velero_enabled             = true
    velero_backup_location     = "s3"
    velero_backup_retention    = "720h"
    enable_cross_region_backup = true
    backup_region              = "us-west-2"
  }
}

# ===================================================================
# Общие теги
# ===================================================================

variable "common_tags" {
  description = "Общие теги для всех ресурсов"
  type        = map(string)
  default = {
    Environment     = "dev"
    ManagedBy      = "terraform"
    Owner          = "platform-engineering"
    CloudProvider  = "aws"
    Architecture   = "event-driven-microservices"
  }
}
# ===================================================================
# Root Module Variables - FinPortIQ Platform
# ===================================================================

variable "project_name" {
  description = "Имя проекта для именования ресурсов"
  type        = string
}

variable "environment" {
  description = "Окружение (dev, staging, prod)"
  type        = string
}

variable "region" {
  description = "AWS регион"
  type        = string
}

# ===================================================================
# Optional Services Configuration
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
# VPC Configuration
# ===================================================================

variable "vpc_cidr" {
  description = "CIDR блок для VPC"
  type        = string
}

variable "availability_zones_count" {
  description = "Количество зон доступности"
  type        = number
}

variable "private_subnets_count" {
  description = "Количество приватных подсетей на AZ"
  type        = number
}

variable "public_subnets_count" {
  description = "Количество публичных подсетей на AZ"
  type        = number
}

variable "database_subnets_count" {
  description = "Количество подсетей БД на AZ"
  type        = number
}

variable "nat_gateway_count" {
  description = "Количество NAT Gateway"
  type        = number
}

variable "enable_nat_gateway" {
  description = "Включить NAT Gateway"
  type        = bool
}

variable "single_nat_gateway" {
  description = "Использовать один NAT для всех приватных подсетей"
  type        = bool
}

variable "one_nat_gateway_per_az" {
  description = "Один NAT Gateway на зону доступности"
  type        = bool
}

# ===================================================================
# Cluster Configuration
# ===================================================================

variable "base_cluster_enabled" {
  description = "Включить базовый кластер"
  type        = bool
}

variable "platform_cluster_enabled" {
  description = "Включить кластер платформенных сервисов"
  type        = bool
}

variable "event_processing_cluster_enabled" {
  description = "Включить кластер обработки событий"
  type        = bool
}

variable "base_cluster_config" {
  description = "Конфигурация базового кластера"
  type        = any
}

variable "platform_cluster_config" {
  description = "Конфигурация кластера платформенных сервисов"
  type        = any
}

variable "event_processing_cluster_config" {
  description = "Конфигурация кластера обработки событий"
  type        = any
  default     = null
}

variable "security_config" {
  description = "Конфигурация безопасности кластеров"
  type        = any
}

variable "network_security_config" {
  description = "Конфигурация сетевой безопасности"
  type        = any
}

variable "cluster_addons" {
  description = "Конфигурация аддонов EKS"
  type        = any
}

variable "enable_irsa" {
  description = "Включить IAM роли для сервисных аккаунтов"
  type        = bool
}

variable "irsa_roles" {
  description = "Конфигурация IRSA ролей"
  type        = any
}

variable "data_storage_config" {
  description = "Конфигурация хранения данных"
  type        = any
}

variable "observability_config" {
  description = "Конфигурация наблюдаемости и мониторинга"
  type        = any
}

variable "backup_config" {
  description = "Конфигурация резервного копирования"
  type        = any
}

variable "common_tags" {
  description = "Общие теги для всех ресурсов"
  type        = map(string)
}
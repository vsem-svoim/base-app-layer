# ===================================================================
# Информация об инфраструктуре
# ===================================================================

# Информация о VPC и сети
output "vpc_info" {
  description = "Детали конфигурации VPC"
  value = {
    vpc_id              = module.multi_cluster_eks.vpc_id
    vpc_cidr            = module.multi_cluster_eks.vpc_cidr_block
    private_subnet_ids  = module.multi_cluster_eks.private_subnet_ids
    public_subnet_ids   = module.multi_cluster_eks.public_subnet_ids
    database_subnet_ids = module.multi_cluster_eks.database_subnet_ids
    nat_gateway_ids     = module.multi_cluster_eks.nat_gateway_ids
    vpc_endpoints       = module.multi_cluster_eks.vpc_endpoints
  }
}

# Информация о базовом кластере
output "base_cluster_info" {
  description = "Информация о базовом кластере данных и AI"
  value = var.base_cluster_enabled ? {
    enabled                = module.multi_cluster_eks.base_cluster_enabled
    cluster_id            = module.multi_cluster_eks.base_cluster_id
    cluster_name          = module.multi_cluster_eks.base_cluster_name
    cluster_endpoint      = module.multi_cluster_eks.base_cluster_endpoint
    cluster_version       = module.multi_cluster_eks.base_cluster_version
    cluster_arn           = module.multi_cluster_eks.base_cluster_arn
    oidc_provider_arn     = module.multi_cluster_eks.base_cluster_oidc_provider_arn
    security_group_ids    = module.multi_cluster_eks.base_cluster_security_group_ids
    node_groups           = module.multi_cluster_eks.base_cluster_node_groups
  } : null
}

output "base_cluster_auth" {
  description = "Данные аутентификации базового кластера"
  value = var.base_cluster_enabled ? {
    certificate_authority_data = module.multi_cluster_eks.base_cluster_certificate_authority_data
    kubectl_config = "aws eks update-kubeconfig --region ${var.region} --name ${module.multi_cluster_eks.base_cluster_name} --alias base-layer"
  } : null
  sensitive = true
}

# Информация о платформенном кластере
output "platform_cluster_info" {
  description = "Информация о кластере платформенных сервисов"
  value = var.platform_cluster_enabled ? {
    enabled                = module.multi_cluster_eks.platform_cluster_enabled
    cluster_id            = module.multi_cluster_eks.platform_cluster_id
    cluster_name          = module.multi_cluster_eks.platform_cluster_name
    cluster_endpoint      = module.multi_cluster_eks.platform_cluster_endpoint
    cluster_version       = module.multi_cluster_eks.platform_cluster_version
    cluster_arn           = module.multi_cluster_eks.platform_cluster_arn
    oidc_provider_arn     = module.multi_cluster_eks.platform_cluster_oidc_provider_arn
    security_group_ids    = module.multi_cluster_eks.platform_cluster_security_group_ids
    node_groups           = module.multi_cluster_eks.platform_cluster_node_groups
  } : null
}

output "platform_cluster_auth" {
  description = "Данные аутентификации платформенного кластера"
  value = var.platform_cluster_enabled ? {
    certificate_authority_data = module.multi_cluster_eks.platform_cluster_certificate_authority_data
    kubectl_config = "aws eks update-kubeconfig --region ${var.region} --name ${module.multi_cluster_eks.platform_cluster_name} --alias platform-services"
  } : null
  sensitive = true
}

# Информация о кластере обработки событий
output "event_processing_cluster_info" {
  description = "Информация о кластере обработки событий"
  value = var.event_processing_cluster_enabled ? {
    enabled                = module.multi_cluster_eks.event_processing_cluster_enabled
    cluster_id            = module.multi_cluster_eks.event_processing_cluster_id
    cluster_name          = module.multi_cluster_eks.event_processing_cluster_name
    cluster_endpoint      = module.multi_cluster_eks.event_processing_cluster_endpoint
    cluster_version       = module.multi_cluster_eks.event_processing_cluster_version
    cluster_arn           = module.multi_cluster_eks.event_processing_cluster_arn
    oidc_provider_arn     = module.multi_cluster_eks.event_processing_cluster_oidc_provider_arn
    security_group_ids    = module.multi_cluster_eks.event_processing_cluster_security_group_ids
    node_groups           = module.multi_cluster_eks.event_processing_cluster_node_groups
  } : null
}

output "event_processing_cluster_auth" {
  description = "Данные аутентификации кластера обработки событий"
  value = var.event_processing_cluster_enabled ? {
    certificate_authority_data = module.multi_cluster_eks.event_processing_cluster_certificate_authority_data
    kubectl_config = "aws eks update-kubeconfig --region ${var.region} --name ${module.multi_cluster_eks.event_processing_cluster_name} --alias event-processing"
  } : null
  sensitive = true
}

# IRSA роли
output "irsa_role_arns" {
  description = "ARN ролей IAM для сервисных аккаунтов"
  value       = module.multi_cluster_eks.irsa_role_arns
}

# Событийная инфраструктура
output "event_infrastructure" {
  description = "Компоненты событийной архитектуры"
  value = {
    kinesis_streams = {
      for stream_name, stream in aws_kinesis_stream.event_streams : stream_name => {
        arn           = stream.arn
        name          = stream.name
        shard_count   = stream.shard_count
      }
    }
    eventbridge_bus = {
      name = aws_cloudwatch_event_bus.microservices_bus.name
      arn  = aws_cloudwatch_event_bus.microservices_bus.arn
    }
    dlq = {
      url = aws_sqs_queue.dlq.url
      arn = aws_sqs_queue.dlq.arn
    }
    log_group = {
      name = aws_cloudwatch_log_group.microservices_logs.name
      arn  = aws_cloudwatch_log_group.microservices_logs.arn
    }
  }
}

# Конфигурация Kubectl для всех кластеров
output "kubectl_commands" {
  description = "Команды для настройки доступа kubectl ко всем кластерам"
  value = {
    base_cluster = var.base_cluster_enabled ? "aws eks update-kubeconfig --region ${var.region} --name ${module.multi_cluster_eks.base_cluster_name} --alias base-layer" : null
    
    platform_cluster = var.platform_cluster_enabled ? "aws eks update-kubeconfig --region ${var.region} --name ${module.multi_cluster_eks.platform_cluster_name} --alias platform-services" : null
    
    event_processing_cluster = var.event_processing_cluster_enabled ? "aws eks update-kubeconfig --region ${var.region} --name ${module.multi_cluster_eks.event_processing_cluster_name} --alias event-processing" : null
    
    all_clusters = join(" && ", compact([
      var.base_cluster_enabled ? "aws eks update-kubeconfig --region ${var.region} --name ${module.multi_cluster_eks.base_cluster_name} --alias base-layer" : "",
      var.platform_cluster_enabled ? "aws eks update-kubeconfig --region ${var.region} --name ${module.multi_cluster_eks.platform_cluster_name} --alias platform-services" : "",
      var.event_processing_cluster_enabled ? "aws eks update-kubeconfig --region ${var.region} --name ${module.multi_cluster_eks.event_processing_cluster_name} --alias event-processing" : ""
    ]))
  }
}

# Безопасность и шифрование
output "security_info" {
  description = "Информация о безопасности и шифровании"
  value = {
    kms_key_arn   = aws_kms_key.events_key.arn
    kms_key_alias = aws_kms_alias.events_key_alias.name
  }
  sensitive = true
}

# Информация о хранении данных
output "data_storage_info" {
  description = "Информация о компонентах хранения данных"
  value = {
    s3_buckets     = module.multi_cluster_eks.s3_bucket_arns
    msk_cluster    = module.multi_cluster_eks.msk_cluster_info
    elasticache    = module.multi_cluster_eks.elasticache_info
  }
}

# Наблюдаемость
output "observability_info" {
  description = "Компоненты наблюдаемости и мониторинга"
  value = {
    prometheus_workspace = module.multi_cluster_eks.prometheus_workspace_info
    grafana_workspace    = module.multi_cluster_eks.grafana_workspace_info
    cloudwatch_insights  = module.multi_cluster_eks.container_insights_enabled
  }
}

# Общая информация для деплоя микросервисов
output "microservices_deployment_info" {
  description = "Информация для деплоя микросервисов"
  value = {
    # Namespace рекомендации
    recommended_namespaces = {
      base_layer = [
        "base-data-ingestion",
        "base-data-processing",
        "base-data-quality",
        "base-ai-ml",
        "base-streaming"
      ]
      platform_services = [
        "argocd",
        "crossplane-system",
        "istio-system",
        "monitoring",
        "logging"
      ]
      event_processing = [
        "kafka",
        "kafka-connect",
        "schema-registry",
        "stream-processing"
      ]
    }

    # Таблицы маршрутизации для событий
    event_routing = {
      kinesis_streams = keys(aws_kinesis_stream.event_streams)
      eventbridge_bus = aws_cloudwatch_event_bus.microservices_bus.name
      dlq            = aws_sqs_queue.dlq.name
    }

    # Service Mesh готовность
    service_mesh_ready = true
    istio_namespaces = [
      "istio-system",
      "istio-gateway"
    ]
  }
}
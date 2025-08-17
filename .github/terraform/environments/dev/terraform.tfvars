# ===================================================================
# Конфигурация платформы FinPortIQ - AWS Multi-Cluster
# ===================================================================

# Базовая конфигурация
project_name = "base-app-layer"
environment  = "dev"
region      = "us-east-1"

# ===================================================================
# Конфигурация опциональных сервисов
# ===================================================================
# Базовые приложения (всегда включены)
enable_base_data_ingestion = true
enable_argocd             = true

# Shared Services (включены по умолчанию)
enable_airflow            = true
enable_monitoring         = true
enable_ml_platform        = true

# Опциональные сервисы (выключены по умолчанию для экономии ресурсов)
enable_kafka_cluster      = false
enable_event_processing   = false
enable_istio_service_mesh = false
enable_backup_services    = false
enable_gpu_workloads      = false
enable_big_data_processing = false

# ===================================================================
# Конфигурация VPC для микросервисной архитектуры
# ===================================================================
vpc_cidr                 = "10.0.0.0/16"
availability_zones_count = 3
private_subnets_count    = 2    # Разделение для приложений и данных
public_subnets_count     = 1
database_subnets_count   = 1    # Отдельные подсети для БД

# Конфигурация NAT Gateway для высокой доступности
nat_gateway_count      = 3      # По одному на AZ
enable_nat_gateway     = true
single_nat_gateway     = false  # Для производственной готовности
one_nat_gateway_per_az = true   # HA конфигурация

# ===================================================================
# Расширенная конфигурация безопасности
# ===================================================================
security_config = {
  enable_pod_security_standards = true
  pod_security_standard          = "restricted"
  enable_secrets_encryption      = true
  kms_key_rotation_enabled      = true
  enable_audit_logging          = true
  audit_log_retention_days      = 90
}

network_security_config = {
  waf_enabled                           = true
  enable_microservice_security_groups   = true
  enable_network_policies               = true
  vpc_endpoints = [
    "s3", "ecr.api", "ecr.dkr", "logs",
    "monitoring", "events", "sqs", "sns",
    "secretsmanager", "ssm"
  ]
}

# ===================================================================
# Конфигурация кластеров
# ===================================================================
base_cluster_enabled             = true
platform_cluster_enabled        = true
event_processing_cluster_enabled = false

# ===================================================================
# Базовый кластер - обработка данных и AI
# ===================================================================
base_cluster_config = {
  name               = "base-layer"
  version            = "1.33"
  enable_fargate     = true
  enable_managed_nodes = true

  endpoint_config = {
    private_access      = true
    public_access       = true
    public_access_cidrs = ["0.0.0.0/0"]  # Ограничить в продакшене
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Fargate для событийных и AI workloads
  fargate_profiles = {
    base_data_ingestion = {
      namespace_selectors = ["base-data-ingestion", "kafka-connect"]
      label_selectors    = {}
      subnet_type        = "private"
    }
    base_streaming = {
      namespace_selectors = ["base-streaming", "kinesis-analytics"]
      label_selectors    = {
        "workload-type" = "streaming"
      }
      subnet_type = "private"
    }
    base_processing = {
      namespace_selectors = ["base-data-processing", "base-data-quality", "spark-jobs"]
      label_selectors    = {}
      subnet_type        = "private"
    }
    base_ai_workloads = {
      namespace_selectors = ["base-ai-*", "sagemaker-*", "model-serving"]
      label_selectors    = {
        "workload-type" = "ai-processing"
      }
      subnet_type = "private"
    }
  }

  # Оптимизированные группы узлов
  managed_node_groups = {
    # Spot экземпляры для приложений
    base_apps_spot = {
      instance_types = ["m7i.2xlarge", "m7i.4xlarge", "m6i.2xlarge", "m6i.4xlarge"]
      capacity_type  = "SPOT"
      min_size      = 1
      max_size      = 2
      desired_size  = 1
      disk_size     = 100
      disk_type     = "gp3"
      ami_type      = "BOTTLEROCKET_x86_64"

      labels = {
        NodeGroup    = "base-apps-spot"
        Environment  = "dev"
        WorkloadType = "base-apps"
        CostProfile  = "optimized"
      }

      mixed_instances_policy = {
        instances_distribution = {
          on_demand_percentage     = 40  # More on-demand for stability
          spot_allocation_strategy = "price-capacity-optimized"
          spot_instance_pools      = 2
        }
      }

      scaling_config = {
        desired_size = 1
        max_size     = 2
        min_size     = 1
      }
    }

    # Отключены для экономии ресурсов - включаются через enable_big_data_processing флаг
    # base_data_processing_graviton = {
    #   instance_types = ["r7g.2xlarge", "r7g.4xlarge", "r7g.8xlarge"]
    #   capacity_type  = "SPOT"
    #   min_size      = 0
    #   max_size      = 2
    #   desired_size  = 0
    #   disk_size     = 200
    #   disk_type     = "gp3"
    #   ami_type      = "BOTTLEROCKET_ARM_64"
    #
    #   labels = {
    #     NodeGroup    = "base-data-processing-graviton"
    #     Environment  = "dev"
    #     WorkloadType = "data-processing"
    #     Architecture = "arm64"
    #   }
    #
    #   taints = {
    #     data_processing = {
    #       key    = "data-processing"
    #       value  = "true"
    #       effect = "NO_SCHEDULE"
    #     }
    #     arm64 = {
    #       key    = "kubernetes.io/arch"
    #       value  = "arm64"
    #       effect = "NO_SCHEDULE"
    #     }
    #   }
    # }

    # Отключены для экономии ресурсов - включаются через enable_big_data_processing флаг
    # base_big_data = {
    #   instance_types = ["r7i.8xlarge", "r7i.12xlarge", "r7i.16xlarge"]
    #   capacity_type  = "SPOT"
    #   min_size      = 0
    #   max_size      = 2
    #   desired_size  = 0
    #   disk_size     = 1000
    #   disk_type     = "gp3"
    #   ami_type      = "BOTTLEROCKET_x86_64"
    #
    #   labels = {
    #     NodeGroup    = "base-big-data"
    #     Environment  = "dev"
    #     WorkloadType = "big-data"
    #   }
    #
    #   taints = {
    #     big_data = {
    #       key    = "big-data"
    #       value  = "true"
    #       effect = "NO_SCHEDULE"
    #     }
    #   }
    # }
  }
}

# ===================================================================
# Кластер платформенных сервисов
# ===================================================================
platform_cluster_config = {
  name               = "platform-services"
  version            = "1.33"
  enable_fargate     = true
  enable_managed_nodes = true

  endpoint_config = {
    private_access      = true
    public_access       = true
    public_access_cidrs = ["0.0.0.0/0"]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # Fargate для платформенных сервисов
  fargate_profiles = {
    platform_system = {
      namespace_selectors = ["kube-system", "kube-public"]
      label_selectors    = {}
      subnet_type        = "private"
    }
    platform_gitops = {
      namespace_selectors = ["argocd", "argo-events", "argo-workflows", "tekton-pipelines"]
      label_selectors    = {}
      subnet_type        = "private"
    }
    platform_infrastructure = {
      namespace_selectors = ["crossplane-system", "istio-system", "istio-gateway", "cert-manager"]
      label_selectors    = {}
      subnet_type        = "private"
    }
    platform_monitoring = {
      namespace_selectors = ["monitoring", "logging", "jaeger", "kiali", "prometheus-operator"]
      label_selectors    = {}
      subnet_type        = "private"
    }
    platform_event_mesh = {
      namespace_selectors = ["knative-*", "dapr-*", "event-mesh"]
      label_selectors    = {
        "workload-type" = "event-driven"
      }
      subnet_type = "private"
    }
    ml_platform = {
      namespace_selectors = ["mlflow", "kubeflow", "feast", "seldon"]
      label_selectors    = {
        "workload-type" = "ml-platform"
      }
      subnet_type = "private"
    }
  }

  managed_node_groups = {
    # Смешанные экземпляры для платформенных сервисов
    platform_services_mixed = {
      instance_types = ["m7i.2xlarge", "m7i.4xlarge", "m6i.2xlarge", "m6i.4xlarge"]
      capacity_type  = "MIXED"
      min_size      = 1
      max_size      = 2
      desired_size  = 1
      disk_size     = 200
      disk_type     = "gp3"
      ami_type      = "BOTTLEROCKET_x86_64"

      mixed_instances_policy = {
        instances_distribution = {
          on_demand_percentage     = 40  # Больше on-demand для стабильности
          spot_allocation_strategy = "price-capacity-optimized"
        }
      }

      labels = {
        NodeGroup    = "platform-services-mixed"
        Environment  = "dev"
        WorkloadType = "platform-services"
      }
    }

    # Отключены для экономии ресурсов - включаются через enable_gpu_workloads флаг
    # ml_workloads_gpu = {
    #   instance_types = ["g5.2xlarge", "g5.4xlarge", "g5.8xlarge"]
    #   capacity_type  = "SPOT"
    #   min_size      = 0
    #   max_size      = 2
    #   desired_size  = 0
    #   disk_size     = 500
    #   disk_type     = "gp3"
    #   ami_type      = "BOTTLEROCKET_x86_64_NVIDIA"
    #
    #   labels = {
    #     NodeGroup       = "ml-workloads-gpu"
    #     Environment     = "dev"
    #     WorkloadType    = "machine-learning"
    #     AcceleratorType = "nvidia-gpu"
    #   }
    #
    #   taints = {
    #     gpu = {
    #       key    = "nvidia.com/gpu"
    #       value  = "true"
    #       effect = "NO_SCHEDULE"
    #     }
    #   }
    # }

    # Отключены для экономии ресурсов - включаются через enable_event_processing флаг
    # event_processing = {
    #   instance_types = ["c7i.4xlarge", "c7i.8xlarge", "c7i.12xlarge", "i4i.2xlarge", "i4i.4xlarge"]
    #   capacity_type  = "ON_DEMAND"
    #   min_size      = 0
    #   max_size      = 2
    #   desired_size  = 0
    #   disk_size     = 200
    #   disk_type     = "gp3"
    #   ami_type      = "BOTTLEROCKET_x86_64"
    #
    #   labels = {
    #     NodeGroup    = "event-processing"
    #     Environment  = "dev"
    #     WorkloadType = "event-processing"
    #   }
    #
    #   taints = {
    #     event_processing = {
    #       key    = "event-processing"
    #       value  = "true"
    #       effect = "NO_SCHEDULE"
    #     }
    #   }
    # }
  }
}

# ===================================================================
# Кластер обработки событий (ОТКЛЮЧЕН для экономии ресурсов)
# Включается через event_processing_cluster_enabled = true
# ===================================================================
# event_processing_cluster_config = {
#   name               = "event-processing"
#   version            = "1.33"
#   enable_fargate     = false  # Только узлы для производительности
#   enable_managed_nodes = true
#
#   endpoint_config = {
#     private_access      = true
#     public_access       = false  # Приватный кластер
#     public_access_cidrs = []
#   }
#
#   enabled_cluster_log_types = ["api", "audit"]
#
#   managed_node_groups = {
#     # Kafka кластер с NVMe
#     kafka_cluster = {
#       instance_types = ["i4i.2xlarge", "i4i.4xlarge", "i4i.8xlarge"]
#       capacity_type  = "ON_DEMAND"
#       min_size      = 0
#       max_size      = 2
#       desired_size  = 0
#       disk_size     = 100  # Используем instance storage
#       disk_type     = "gp3"
#       ami_type      = "BOTTLEROCKET_x86_64"
#
#       labels = {
#         NodeGroup    = "kafka-cluster"
#         Environment  = "dev"
#         WorkloadType = "kafka"
#       }
#
#       taints = {
#         kafka = {
#           key    = "kafka"
#           value  = "true"
#           effect = "NO_SCHEDULE"
#         }
#       }
#     }
#
#     # Обработка потоков данных
#     stream_processing = {
#       instance_types = ["c7i.2xlarge", "c7i.4xlarge", "c7i.8xlarge", "r7i.2xlarge", "r7i.4xlarge"]
#       capacity_type  = "SPOT"
#       min_size      = 0
#       max_size      = 2
#       desired_size  = 0
#       disk_size     = 200
#       disk_type     = "gp3"
#       ami_type      = "BOTTLEROCKET_x86_64"
#
#       labels = {
#         NodeGroup    = "stream-processing"
#         Environment  = "dev"
#         WorkloadType = "stream-processing"
#       }
#     }
#   }
# }

# ===================================================================
# Расширенные аддоны EKS
# ===================================================================
cluster_addons = {
  coredns = {
    most_recent           = true
    addon_version        = ""
    configuration_values = jsonencode({
      computeType = "Fargate"
    })
  }
  kube-proxy = {
    most_recent           = true
    addon_version        = ""
    configuration_values = ""
  }
  vpc-cni = {
    most_recent    = true
    addon_version = ""
    configuration_values = jsonencode({
      env = {
        ENABLE_PREFIX_DELEGATION = "true"
        WARM_PREFIX_TARGET       = "1"
        ENABLE_POD_ENI          = "true"
        ENABLE_NETWORK_POLICY   = "true"
      }
    })
  }
  aws-ebs-csi-driver = {
    most_recent           = true
    addon_version        = ""
    configuration_values = jsonencode({
      defaultStorageClass = {
        enabled = true
        parameters = {
          type       = "gp3"
          throughput = "125"
          iops      = "3000"
        }
      }
    })
  }
  aws-efs-csi-driver = {
    most_recent           = true
    addon_version        = ""
    configuration_values = ""
  }
}

# ===================================================================
# IRSA роли с минимальными привилегиями
# ===================================================================
enable_irsa = true

irsa_roles = {
  # Crossplane для управления инфраструктурой
  crossplane = {
    policy_arns = [
      "arn:aws:iam::aws:policy/AmazonEC2FullAccess",
      "arn:aws:iam::aws:policy/AmazonS3FullAccess",
      "arn:aws:iam::aws:policy/AmazonRDSFullAccess",
      "arn:aws:iam::aws:policy/AmazonElastiCacheFullAccess"
    ]
    namespaces       = ["crossplane-system"]
    service_accounts = ["crossplane"]
  }

  # ArgoCD для GitOps
  argocd = {
    policy_arns = [
      "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
      "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    ]
    namespaces       = ["argocd"]
    service_accounts = ["argocd-server", "argocd-application-controller"]
  }

  # Airflow для оркестрации данных
  airflow = {
    policy_arns = [
      "arn:aws:iam::aws:policy/AmazonS3FullAccess",
      "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess",
      "arn:aws:iam::aws:policy/AmazonEMRFullAccess"
    ]
    namespaces       = ["airflow"]
    service_accounts = ["airflow-scheduler", "airflow-webserver", "airflow-worker"]
  }

  # Мониторинг и наблюдаемость
  monitoring = {
    policy_arns = [
      "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess",
      "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess",
      "arn:aws:iam::aws:policy/AmazonPrometheusRemoteWriteAccess"
    ]
    namespaces       = ["monitoring"]
    service_accounts = ["prometheus", "grafana", "cloudwatch-agent"]
  }

  # Событийная архитектура
  event_bridge = {
    policy_arns = [
      "arn:aws:iam::aws:policy/AmazonEventBridgeFullAccess",
      "arn:aws:iam::aws:policy/AmazonSQSFullAccess",
      "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
    ]
    namespaces       = ["event-mesh", "dapr-system"]
    service_accounts = ["event-processor", "dapr-operator"]
  }

  # Kafka/MSK
  kafka = {
    policy_arns = [
      "arn:aws:iam::aws:policy/AmazonMSKFullAccess",
      "arn:aws:iam::aws:policy/AmazonKinesisFullAccess"
    ]
    namespaces       = ["kafka", "kafka-connect"]
    service_accounts = ["kafka-connect", "schema-registry"]
  }

  # ML/AI сервисы
  ml_services = {
    policy_arns = [
      "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess",
      "arn:aws:iam::aws:policy/AmazonBedrockFullAccess"
    ]
    namespaces       = ["mlflow", "kubeflow", "sagemaker-operator"]
    service_accounts = ["mlflow", "kubeflow-pipelines"]
  }
}

# ===================================================================
# Конфигурация хранения данных
# ===================================================================
data_storage_config = {
  s3_buckets = {
    raw_data = {
      name                    = "raw-data-lake"
      versioning             = true
      lifecycle_rules        = true
      glacier_transition_days = 30
    }
    processed_data = {
      name                    = "processed-data-lake"
      versioning             = true
      lifecycle_rules        = true
      glacier_transition_days = 90
    }
    event_archive = {
      name                    = "event-archive"
      versioning             = true
      glacier_transition_days = 30
    }
  }

  msk_config = {
    kafka_version         = "3.6.0"
    instance_type        = "kafka.m7g.2xlarge"
    ebs_volume_size      = 1000
    auto_scaling_enabled = true
  }

  elasticache_config = {
    node_type                   = "cache.r7g.2xlarge"
    num_cache_nodes            = 3
    automatic_failover_enabled = true
  }
}

# ===================================================================
# Конфигурация наблюдаемости
# ===================================================================
observability_config = {
  amp_enabled              = true
  amp_workspace_name       = "finportiq-prometheus"
  amg_enabled              = true
  amg_workspace_name       = "finportiq-grafana"
  otel_enabled             = true
  xray_enabled             = true
  container_insights_enabled = true
}

# ===================================================================
# Конфигурация резервного копирования
# ===================================================================
backup_config = {
  ebs_backup_enabled         = true
  ebs_backup_retention_days  = 30
  velero_enabled             = true
  velero_backup_location     = "s3"
  velero_backup_retention    = "720h"
  enable_cross_region_backup = true
  backup_region              = "us-west-2"
}

# ===================================================================
# Расширенные общие теги
# ===================================================================
common_tags = {
  Environment     = "dev"
  Project        = "base-app-layer"
  ManagedBy      = "terraform"
  Owner          = "platform-engineering"
  CloudProvider  = "aws"
  Architecture   = "event-driven-microservices"
  CostCenter     = "platform-engineering"
  Backup         = "required"
  Monitoring     = "enabled"
  Security       = "enhanced"
  DataClass      = "internal"
  Compliance     = "sox"
  AutoShutdown   = "enabled"
  PatchGroup     = "platform"
}
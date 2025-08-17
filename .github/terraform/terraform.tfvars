# ===================================================================
# FinPortIQ Platform - Root Module Configuration
# ===================================================================

# Basic Configuration
project_name = "base-app-layer"
environment  = "dev"
region      = "us-east-1"

# ===================================================================
# Optional Services (Minimal Configuration)
# ===================================================================
# Base applications (always enabled)
enable_base_data_ingestion = true
enable_argocd             = true

# Shared Services (enabled by default)
enable_airflow            = true
enable_monitoring         = true
enable_ml_platform        = true

# Optional services (disabled for cost savings)
enable_kafka_cluster      = false
enable_event_processing   = false
enable_istio_service_mesh = false
enable_backup_services    = false
enable_gpu_workloads      = false
enable_big_data_processing = false

# ===================================================================
# VPC Configuration
# ===================================================================
vpc_cidr                 = "10.0.0.0/16"
availability_zones_count = 3
private_subnets_count    = 2
public_subnets_count     = 1
database_subnets_count   = 1

nat_gateway_count        = 3
enable_nat_gateway       = true
single_nat_gateway       = false
one_nat_gateway_per_az   = true

# ===================================================================
# Cluster Configuration
# ===================================================================
base_cluster_enabled             = true
platform_cluster_enabled        = true
event_processing_cluster_enabled = false

# Security Configuration
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

# Base Cluster Configuration (Minimal)
base_cluster_config = {
  name               = "base-layer"
  version            = "1.33"
  enable_fargate     = true
  enable_managed_nodes = true

  endpoint_config = {
    private_access      = true
    public_access       = true
    public_access_cidrs = ["0.0.0.0/0"]
  }

  enabled_cluster_log_types = ["api", "audit"]

  fargate_profiles = {
    base_data_ingestion = {
      namespace_selectors = ["base-data-ingestion"]
      label_selectors    = {}
      subnet_type        = "private"
    }
  }

  managed_node_groups = {
    base_apps_spot = {
      instance_types = ["m7i.2xlarge", "m7i.4xlarge"]
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
          on_demand_percentage     = 40
          spot_allocation_strategy = "price-capacity-optimized"
          spot_instance_pools      = 2
        }
      }
    }
  }
}

# Platform Cluster Configuration (Minimal)
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

  enabled_cluster_log_types = ["api", "audit"]

  fargate_profiles = {
    platform_gitops = {
      namespace_selectors = ["argocd", "argo-events", "argo-workflows"]
      label_selectors    = {}
      subnet_type        = "private"
    }
    platform_monitoring = {
      namespace_selectors = ["monitoring"]
      label_selectors    = {}
      subnet_type        = "private"
    }
    ml_platform = {
      namespace_selectors = ["mlflow", "kubeflow"]
      label_selectors    = {}
      subnet_type        = "private"
    }
  }

  managed_node_groups = {
    platform_services_mixed = {
      instance_types = ["m7i.2xlarge", "m7i.4xlarge"]
      capacity_type  = "MIXED"
      min_size      = 1
      max_size      = 2
      desired_size  = 1
      disk_size     = 200
      disk_type     = "gp3"
      ami_type      = "BOTTLEROCKET_x86_64"

      mixed_instances_policy = {
        instances_distribution = {
          on_demand_percentage     = 40
          spot_allocation_strategy = "price-capacity-optimized"
        }
      }

      labels = {
        NodeGroup    = "platform-services-mixed"
        Environment  = "dev"
        WorkloadType = "platform-services"
      }
    }
  }
}

# EKS Addons
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
}

# IRSA Configuration
enable_irsa = true

irsa_roles = {
  argocd = {
    policy_arns = [
      "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
      "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
    ]
    namespaces       = ["argocd"]
    service_accounts = ["argocd-server", "argocd-application-controller"]
  }
  airflow = {
    policy_arns = [
      "arn:aws:iam::aws:policy/AmazonS3FullAccess",
      "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
    ]
    namespaces       = ["airflow"]
    service_accounts = ["airflow-scheduler", "airflow-webserver"]
  }
  monitoring = {
    policy_arns = [
      "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess",
      "arn:aws:iam::aws:policy/AmazonPrometheusRemoteWriteAccess"
    ]
    namespaces       = ["monitoring"]
    service_accounts = ["prometheus", "grafana"]
  }
}

# Storage Configuration (Minimal)
data_storage_config = {
  s3_buckets = {
    raw_data = {
      name                    = "raw-data-lake"
      versioning             = true
      lifecycle_rules        = true
      glacier_transition_days = 30
    }
  }
}

# Observability Configuration
observability_config = {
  amp_enabled              = true
  amp_workspace_name       = "finportiq-prometheus"
  amg_enabled              = true
  amg_workspace_name       = "finportiq-grafana"
  otel_enabled             = true
  xray_enabled             = false
  container_insights_enabled = true
}

# Backup Configuration (Minimal)
backup_config = {
  ebs_backup_enabled         = true
  ebs_backup_retention_days  = 30
  velero_enabled             = false
  enable_cross_region_backup = false
}

# Common Tags
common_tags = {
  Environment     = "dev"
  Project        = "base-app-layer"
  ManagedBy      = "terraform"
  Owner          = "platform-engineering"
  CloudProvider  = "aws"
  Architecture   = "minimal-microservices"
  CostCenter     = "platform-engineering"
  Monitoring     = "enabled"
  Security       = "enhanced"
  AutoShutdown   = "enabled"
}
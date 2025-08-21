# ===================================================================
# AWS Dev Environment Configuration
# ===================================================================

# Basic Configuration
project_name = "base-app-layer"
environment  = "dev"
region      = "us-east-1"
aws_profile = "default"

# ===================================================================
# Service Flags (Minimal Configuration for Cost Optimization)
# ===================================================================

# Core Services (Enabled)
base_cluster_enabled     = true
platform_cluster_enabled = true
enable_monitoring        = true

# Optional Services (Disabled for cost savings)
enable_data_storage = false
enable_databases    = false
enable_service_iam  = false
enable_backup       = false

# ===================================================================
# VPC Configuration
# ===================================================================
vpc_cidr                 = "10.0.0.0/16"
availability_zones_count = 2
private_subnets_count    = 2
public_subnets_count     = 1
database_subnets_count   = 1

# NAT Gateway Configuration (Cost optimized - single NAT gateway)
nat_gateway_count        = 1
enable_nat_gateway       = true
single_nat_gateway       = true
one_nat_gateway_per_az   = false

# ===================================================================
# EKS Configuration (Cost Optimized)
# ===================================================================

# Base Cluster (Data Processing)
base_cluster_config = {
  version            = "1.33"
  enable_fargate     = true
  enable_managed_nodes = true
  
  fargate_profiles = {
    base_data_ingestion = {
      namespace_selectors = ["base-data-ingestion", "base-data-quality"]
      label_selectors    = {}
      subnet_type        = "private"
    }
  }
  
  managed_node_groups = {
    base_apps = {
      instance_types = ["m7i.2xlarge", "m7i.4xlarge", "m6i.2xlarge"]
      capacity_type  = "SPOT"
      min_size      = 1
      max_size      = 2
      desired_size  = 1
      disk_size     = 100
      disk_type     = "gp3"
      ami_type      = "BOTTLEROCKET_x86_64"
      
      labels = {
        NodeGroup    = "base-apps"
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
    }
  }
}

# Platform Cluster (GitOps & Platform Services)
platform_cluster_config = {
  version            = "1.33"
  enable_fargate     = true
  enable_managed_nodes = true
  
  fargate_profiles = {
    platform_gitops = {
      namespace_selectors = ["argo-events", "argo-workflows"]
      label_selectors    = {}
      subnet_type        = "private"
    }
    platform_monitoring = {
      namespace_selectors = ["monitoring", "logging"]
      label_selectors    = {}
      subnet_type        = "private"
    }
    ml_platform = {
      namespace_selectors = ["mlflow", "kubeflow", "seldon"]
      label_selectors    = {}
      subnet_type        = "private"
    }
  }
  
  managed_node_groups = {
    # System workloads (ArgoCD, Load Balancers) - 100% On-Demand for stability
    platform_system = {
      instance_types = ["c7i.xlarge", "c7i.2xlarge"]
      capacity_type  = "ON_DEMAND"
      min_size      = 1
      max_size      = 3
      desired_size  = 1
      disk_size     = 100
      disk_type     = "gp3"
      ami_type      = "BOTTLEROCKET_x86_64"
      
      labels = {
        NodeGroup    = "platform-system"
        Environment  = "dev"
        WorkloadType = "system"
      }
    }
    
    # General workloads (monitoring, etc) - 60% On-Demand, 40% Spot
    platform_general = {
      instance_types = ["c7i.xlarge", "c7i.2xlarge", "c7i.4xlarge", "r7i.xlarge", "r7i.2xlarge"]
      capacity_type  = "SPOT"
      min_size      = 1
      max_size      = 3
      desired_size  = 1
      disk_size     = 150
      disk_type     = "gp3"
      ami_type      = "BOTTLEROCKET_x86_64"
      
      labels = {
        NodeGroup    = "platform-general"
        Environment  = "dev"
        WorkloadType = "general"
      }
      
      mixed_instances_policy = {
        instances_distribution = {
          on_demand_percentage     = 60
          spot_allocation_strategy = "price-capacity-optimized"
        }
      }
    }
    
    # Compute workloads (ML, data processing) - 30% On-Demand, 70% Spot
    platform_compute = {
      instance_types = ["c7i.xlarge", "c7i.2xlarge", "c7i.4xlarge"]
      capacity_type  = "SPOT"
      min_size      = 1
      max_size      = 3
      desired_size  = 1
      disk_size     = 200
      disk_type     = "gp3"
      ami_type      = "BOTTLEROCKET_x86_64"
      
      labels = {
        NodeGroup    = "platform-compute"
        Environment  = "dev"
        WorkloadType = "compute"
      }
      
      mixed_instances_policy = {
        instances_distribution = {
          on_demand_percentage     = 30
          spot_allocation_strategy = "price-capacity-optimized"
        }
      }
    }
    
    # Memory workloads (databases, caching) - 50% On-Demand, 50% Spot
    platform_memory = {
      instance_types = ["r7i.xlarge", "r7i.2xlarge", "r7i.4xlarge"]
      capacity_type  = "SPOT"
      min_size      = 1
      max_size      = 3
      desired_size  = 1
      disk_size     = 200
      disk_type     = "gp3"
      ami_type      = "BOTTLEROCKET_x86_64"
      
      labels = {
        NodeGroup    = "platform-memory"
        Environment  = "dev"
        WorkloadType = "memory"
      }
      
      mixed_instances_policy = {
        instances_distribution = {
          on_demand_percentage     = 50
          spot_allocation_strategy = "price-capacity-optimized"
        }
      }
    }
    
    # GPU workloads (ML training, inference) - min 0, desired 0, max 2
    platform_gpu = {
      instance_types = ["g5.xlarge", "g5.2xlarge", "g5.4xlarge"]
      capacity_type  = "SPOT"
      min_size      = 0
      max_size      = 2
      desired_size  = 0
      disk_size     = 300
      disk_type     = "gp3"
      ami_type      = "AL2_x86_64_GPU"
      
      labels = {
        NodeGroup    = "platform-gpu"
        Environment  = "dev"
        WorkloadType = "gpu"
        "nvidia.com/gpu" = "true"
      }
      
      taints = [
        {
          key    = "nvidia.com/gpu"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      ]
      
      mixed_instances_policy = {
        instances_distribution = {
          on_demand_percentage     = 40
          spot_allocation_strategy = "price-capacity-optimized"
        }
      }
    }
  }
}

# ===================================================================
# EKS Addons
# ===================================================================
cluster_addons = {
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
}

# ===================================================================
# IRSA Configuration
# ===================================================================
enable_irsa = true

irsa_roles = {
  argocd = {
    policy_arns = [
      "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
    ]
    namespaces       = ["argocd"]
    service_accounts = ["argocd-server", "argocd-application-controller"]
  }
  airflow = {
    policy_arns = [
      "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess",
      "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
    ]
    namespaces       = ["airflow"]
    service_accounts = ["airflow-scheduler", "airflow-webserver"]
  }
  monitoring = {
    policy_arns = [
      "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
    ]
    namespaces       = ["monitoring"]
    service_accounts = ["prometheus", "grafana"]
  }
  aws_load_balancer_controller = {
    policy_arns = [
      "arn:aws:iam::084129280818:policy/AWSLoadBalancerControllerIAMPolicy"
    ]
    namespaces       = ["kube-system"]
    service_accounts = ["aws-load-balancer-controller"]
  }
}

# ===================================================================
# Storage Configuration (Minimal)
# ===================================================================
data_storage_config = {
  s3_buckets = {
    raw_data = {
      name                    = "base-app-layer-raw-data-dev"
      versioning             = true
      lifecycle_rules        = true
      glacier_transition_days = 30
    }
  }
}

# ===================================================================
# Crossplane Configuration (Infrastructure as Code Platform)
# ===================================================================
enable_crossplane                     = false
crossplane_namespace                  = "crossplane-system"
crossplane_version                   = "1.17.1"
enable_crossplane_aws_provider       = true
enable_crossplane_compositions       = true
enable_crossplane_metrics            = true
crossplane_aws_credentials_source    = "IRSA"
crossplane_create_irsa_role          = true

# ===================================================================
# Common Tags
# ===================================================================
common_tags = {
  Project        = "base-app-layer"
  Environment    = "dev"
  ManagedBy      = "terraform"
  Owner          = "platform-engineering"
  CloudProvider  = "aws"
  Architecture   = "minimal-microservices"
  CostOptimized  = "true"
  AutoShutdown   = "enabled"
  DeploymentType = "minimal"
  Crossplane     = "enabled"
}
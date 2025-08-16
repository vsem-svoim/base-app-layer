# ===================================================================
# FinPortIQ Platform - AWS Multi-Cluster Configuration
# ===================================================================
# This file contains all configurable parameters for the AWS infrastructure
# Modify values according to your requirements

# Basic Configuration
project_name = "base-app-layer"
environment  = "dev"
region      = "us-east-1"

# ===================================================================
# VPC Configuration
# ===================================================================
vpc_cidr                = "10.0.0.0/16"
availability_zones_count = 3               # Number of AZs to use (2-6)
private_subnets_count   = 1                # Private subnets per AZ
public_subnets_count    = 1                # Public subnets per AZ

# NAT Gateway Configuration
nat_gateway_count       = 3                # Total number of NAT gateways
enable_nat_gateway      = true             # Enable NAT gateways
single_nat_gateway      = false            # Use single NAT for all private subnets
one_nat_gateway_per_az  = true             # Use one NAT per AZ (recommended for HA)

# ===================================================================
# Cluster Configuration
# ===================================================================
base_cluster_enabled     = true            # Enable BASE layer cluster
platform_cluster_enabled = true            # Enable platform services cluster

# ===================================================================
# BASE Layer Cluster Configuration
# ===================================================================
base_cluster_config = {
  name               = "base-layer"
  version            = "1.33"              # EKS version 1.33
  enable_fargate     = true                # Enable Fargate profiles
  enable_managed_nodes = true              # Enable managed node groups

  # Fargate profiles for BASE layer
  fargate_profiles = {
    base_components = {
      namespace_selectors = ["base-*"]     # All base-* namespaces
      label_selectors    = {}              # No specific label selectors
    }
  }

  # Managed node groups for BASE layer
  managed_node_groups = {
    base_compute = {
      instance_types = ["t3.medium", "t3.large"]  # Instance types for BASE workloads
      capacity_type  = "ON_DEMAND"                # ON_DEMAND or SPOT
      min_size      = 1                           # Minimum nodes
      max_size      = 10                          # Maximum nodes
      desired_size  = 3                           # Desired nodes
      disk_size     = 50                          # EBS disk size (GB)
      disk_type     = "gp3"                       # EBS disk type
      ami_type      = "AL2_x86_64"                # AMI type
      labels = {
        NodeGroup   = "base-layer"
        Environment = "dev"
        WorkloadType = "base-components"
      }
      taints = {
        base_layer = {
          key    = "base-layer"
          value  = "true"
          effect = "NO_SCHEDULE"                   # Dedicated to BASE layer
        }
      }
    }
    base_memory_optimized = {
      instance_types = ["r5.large", "r5.xlarge"]  # Memory-optimized for data processing
      capacity_type  = "SPOT"                     # Use SPOT instances for cost savings
      min_size      = 0                           # Can scale to zero
      max_size      = 20                          # Allow high scale for data processing
      desired_size  = 2                           # Start with 2 nodes
      disk_size     = 100                         # Larger disk for data processing
      disk_type     = "gp3"
      ami_type      = "AL2_x86_64"
      labels = {
        NodeGroup   = "base-memory-optimized"
        Environment = "dev"
        WorkloadType = "data-processing"
      }
      taints = {
        memory_optimized = {
          key    = "memory-optimized"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }
    }
  }
}

# ===================================================================
# Platform Services Cluster Configuration
# ===================================================================
platform_cluster_config = {
  name               = "platform-services"
  version            = "1.33"              # EKS version 1.33
  enable_fargate     = true                # Enable Fargate profiles
  enable_managed_nodes = true              # Enable managed node groups

  # Fargate profiles for platform services
  fargate_profiles = {
    platform_default = {
      namespace_selectors = ["default", "kube-system"]
      label_selectors    = {}
    }
    platform_services = {
      namespace_selectors = ["argocd", "crossplane-system", "monitoring"]
      label_selectors    = {}
    }
    ml_platform = {
      namespace_selectors = ["ml-*"]       # All ml-* namespaces
      label_selectors    = {}
    }
  }

  # Managed node groups for platform services
  managed_node_groups = {
    platform_general = {
      instance_types = ["t3.large", "t3.xlarge"]  # General purpose instances
      capacity_type  = "ON_DEMAND"                # Reliable for platform services
      min_size      = 1
      max_size      = 10
      desired_size  = 3
      disk_size     = 100                          # Larger disk for platform services
      disk_type     = "gp3"
      ami_type      = "AL2_x86_64"
      labels = {
        NodeGroup   = "platform-services"
        Environment = "dev"
        WorkloadType = "platform-services"
      }
      taints = {}                                  # No taints - general purpose
    }
    ml_workloads = {
      instance_types = ["m5.large", "m5.xlarge", "m5.2xlarge"]  # Compute optimized for ML
      capacity_type  = "SPOT"                     # Cost-effective for ML training
      min_size      = 0                           # Can scale to zero when not needed
      max_size      = 50                          # Allow high scale for ML workloads
      desired_size  = 2
      disk_size     = 200                         # Large disk for ML datasets
      disk_type     = "gp3"
      ami_type      = "AL2_x86_64"
      labels = {
        NodeGroup   = "ml-workloads"
        Environment = "dev"
        WorkloadType = "machine-learning"
      }
      taints = {
        ml_workload = {
          key    = "ml-workload"
          value  = "true"
          effect = "NO_SCHEDULE"                   # Dedicated to ML workloads
        }
      }
    }
    airflow_workers = {
      instance_types = ["c5.large", "c5.xlarge"]  # Compute optimized for Airflow
      capacity_type  = "ON_DEMAND"                # Reliable for workflow orchestration
      min_size      = 1
      max_size      = 20                          # Allow scaling for high workloads
      desired_size  = 2
      disk_size     = 50
      disk_type     = "gp3"
      ami_type      = "AL2_x86_64"
      labels = {
        NodeGroup   = "airflow-workers"
        Environment = "dev"
        WorkloadType = "workflow-orchestration"
      }
      taints = {
        airflow = {
          key    = "airflow"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }
    }
  }
}

# ===================================================================
# EKS Add-ons Configuration
# ===================================================================
cluster_addons = {
  coredns = {
    most_recent           = true
    addon_version        = ""              # Use most recent
    configuration_values = ""
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
        ENABLE_POD_ENI          = "true"    # Enable pod ENI for better networking
      }
    })
  }
  aws-ebs-csi-driver = {
    most_recent           = true
    addon_version        = ""
    configuration_values = jsonencode({
      defaultStorageClass = {
        enabled = true
      }
    })
  }
}

# ===================================================================
# IAM Roles for Service Accounts (IRSA) Configuration
# ===================================================================
enable_irsa = true

irsa_roles = {
  crossplane = {
    policy_arns      = ["arn:aws:iam::aws:policy/AdministratorAccess"]  # Full access for infrastructure management
    namespaces       = ["crossplane-system"]
    service_accounts = ["crossplane"]
  }
  argocd = {
    policy_arns      = ["arn:aws:iam::aws:policy/AdministratorAccess"]  # Full access for GitOps
    namespaces       = ["argocd"]
    service_accounts = ["argocd-server", "argocd-application-controller"]
  }
  airflow = {
    policy_arns = [
      "arn:aws:iam::aws:policy/AmazonS3FullAccess",                    # S3 access for data processing
      "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"                # EC2 read access
    ]
    namespaces       = ["airflow"]
    service_accounts = ["airflow-scheduler", "airflow-webserver", "airflow-worker"]
  }
  monitoring = {
    policy_arns = [
      "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess",              # CloudWatch metrics
      "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"                # EC2 monitoring
    ]
    namespaces       = ["monitoring"]
    service_accounts = ["prometheus", "grafana"]
  }
}

# ===================================================================
# Common Tags Applied to All Resources
# ===================================================================
common_tags = {
  Environment   = "dev"
  Project       = "base-app-layer"
  ManagedBy     = "terraform"
  Owner         = "platform-engineering"
  CloudProvider = "aws"
  Architecture  = "multi-cluster"
  CostCenter    = "platform-engineering"
  Backup        = "required"
  Monitoring    = "enabled"
}

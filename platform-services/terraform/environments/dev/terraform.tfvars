# ===================================================================
# FinPortIQ Platform - AWS Multi-Cluster Configuration
# ===================================================================
# This file contains all configurable parameters for the AWS infrastructure
# Modify values according to your requirements

# Basic Configuration
project_name = "plat-svc"
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
nat_gateway_count       = 1                # Total number of NAT gateways
enable_nat_gateway      = true             # Enable NAT gateways
single_nat_gateway      = true             # Use single NAT for all private subnets
one_nat_gateway_per_az  = false            # Use one NAT per AZ (recommended for HA)

# ===================================================================
# Cluster Configuration
# ===================================================================
base_cluster_enabled     = false           # Disable BASE layer cluster - run on platform cluster
platform_cluster_enabled = true            # Enable platform services cluster

# ===================================================================
# BASE Layer Cluster Configuration
# ===================================================================
base_cluster_config = {
  name               = "base-layer"
  version            = "1.33"              # EKS version 1.33
  enable_fargate     = true                # Enable Fargate profiles
  enable_managed_nodes = true              # Minimal nodes for system components

  # Fargate profiles for BASE layer
  fargate_profiles = {
    base_components = {
      namespace_selectors = ["base-*"]     # All base-* namespaces (excluding kube-system)
      label_selectors    = {}              # No specific label selectors
    }
  }

  # Managed node groups for BASE layer
  managed_node_groups = {
    system = {
      instance_types = ["t4g.small"]
      capacity_type  = "ON_DEMAND"
      min_size      = 1
      max_size      = 2
      desired_size  = 1
      disk_size     = 20
      disk_type     = "gp3"
      ami_type      = "BOTTLEROCKET_ARM_64"
      labels = {
        NodeGroup   = "system"
        Environment = "dev"
        WorkloadType = "system-components"
      }
      taints = {}  # No taints for system components
    }
    data = {
      instance_types = ["r8g.large", "r8g.xlarge"]  # Latest memory-optimized for data processing
      capacity_type  = "SPOT"
      min_size      = 0
      max_size      = 10
      desired_size  = 1
      disk_size     = 100
      disk_type     = "gp3"
      ami_type      = "BOTTLEROCKET_ARM_64"
      labels = {
        NodeGroup   = "data"
        Environment = "dev"
        WorkloadType = "data-processing"
      }
      taints = {
        data_processing = {
          key    = "data-processing"
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
  name               = "svc"
  version            = "1.33"              # EKS version 1.33
  enable_fargate     = true                # Enable Fargate profiles
  enable_managed_nodes = true              # Minimal nodes for system components

  # Fargate profiles for platform services - only for stateless, auto-scaling workloads
  fargate_profiles = {
    monitoring = {
      namespace_selectors = ["monitoring"]   # Prometheus, Grafana for auto-scaling
      label_selectors    = {
        "fargate-enabled" = "true"           # Only pods explicitly labeled for Fargate
      }
    }
    ml_platform = {
      namespace_selectors = ["ml-*", "mlflow", "kubeflow", "seldon-system"]  # ML platform namespaces for auto-scaling ML workloads
      label_selectors    = {
        "fargate-enabled" = "true"           # Only pods explicitly labeled for Fargate
      }
    }
  }

  # Managed node groups for platform services - dedicated groups for each workload type
  managed_node_groups = {
    system = {
      instance_types = ["r8g.large"]  # Memory-optimized instances for system components
      capacity_type  = "ON_DEMAND"
      min_size      = 1
      max_size      = 3
      desired_size  = 2
      disk_size     = 20
      disk_type     = "gp3"
      ami_type      = "BOTTLEROCKET_ARM_64"
      labels = {
        NodeGroup   = "system"
        Environment = "dev"
        WorkloadType = "system"
      }
      taints = {}  # No taints - accepts system components like crossplane, kube-system
    }
    argocd = {
      instance_types = ["m7g.large"]  # General purpose for GitOps controllers
      capacity_type  = "ON_DEMAND"
      min_size      = 1
      max_size      = 3
      desired_size  = 1
      disk_size     = 30
      disk_type     = "gp3"
      ami_type      = "BOTTLEROCKET_ARM_64"
      labels = {
        NodeGroup   = "argocd"
        Environment = "dev"
        WorkloadType = "argocd"
      }
      taints = {
        argocd = {
          key    = "argocd"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      }
    }
    airflow = {
      instance_types = ["c8g.2xlarge", "c8g.4xlarge"]  # Larger instances to run all airflow services together
      capacity_type  = "ON_DEMAND"
      min_size      = 2
      max_size      = 6
      desired_size  = 2
      disk_size     = 200  # Larger disk for all airflow components
      disk_type     = "gp3"
      ami_type      = "BOTTLEROCKET_ARM_64"
      labels = {
        NodeGroup   = "airflow"
        Environment = "dev"
        WorkloadType = "airflow"
      }
      taints = {}  # Remove taints so all airflow services can schedule easily
    }
    base_apps = {
      instance_types = ["r8g.4xlarge"]  # Memory-optimized instances for AI agents and base layer apps
      capacity_type  = "ON_DEMAND"
      min_size      = 1
      max_size      = 8
      desired_size  = 2
      disk_size     = 100
      disk_type     = "gp3"
      ami_type      = "BOTTLEROCKET_ARM_64"
      labels = {
        NodeGroup   = "base-apps"
        Environment = "dev"
        WorkloadType = "base-apps"
      }
      taints = {
        base_apps = {
          key    = "base-apps"
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
    configuration_values = "{\"env\":{\"ENABLE_PREFIX_DELEGATION\":\"true\",\"WARM_PREFIX_TARGET\":\"1\",\"ENABLE_POD_ENI\":\"true\"}}"
  }
  aws-ebs-csi-driver = {
    most_recent           = true
    addon_version        = ""
    configuration_values = "{\"defaultStorageClass\":{\"enabled\":true}}"
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
  ebs_csi_driver = {
    policy_arns = [
      "arn:aws:iam::aws:policy/AmazonEC2FullAccess"  # Temporary full EC2 access for EBS CSI
    ]
    namespaces       = ["kube-system"]
    service_accounts = ["ebs-csi-controller-sa"]
  }
}

# ===================================================================
# Common Tags Applied to All Resources
# ===================================================================
common_tags = {
  Environment   = "dev"
  Project       = "plat-svc"
  ManagedBy     = "terraform"
  Owner         = "platform-engineering"
  CloudProvider = "aws"
  Architecture  = "multi-cluster"
  CostCenter    = "platform-engineering"
  Backup        = "required"
  Monitoring    = "enabled"
}

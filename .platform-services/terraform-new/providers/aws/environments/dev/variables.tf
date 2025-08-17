# ===================================================================
# AWS Dev Environment Variables
# ===================================================================

# Basic Configuration
variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "base-app-layer"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS profile to use"
  type        = string
  default     = "akovalenko-084129280818-AdministratorAccess"
}

# ===================================================================
# Service Toggle Flags (Cost Optimization)
# ===================================================================

# Core Services (Always Enabled)
variable "base_cluster_enabled" {
  description = "Enable base data processing cluster"
  type        = bool
  default     = true
}

variable "platform_cluster_enabled" {
  description = "Enable platform services cluster"
  type        = bool
  default     = true
}

# Optional Services (Disabled by default for cost savings)
variable "enable_data_storage" {
  description = "Enable S3 data storage resources"
  type        = bool
  default     = false
}

variable "enable_databases" {
  description = "Enable RDS databases"
  type        = bool
  default     = false
}

variable "enable_service_iam" {
  description = "Enable additional IAM service roles"
  type        = bool
  default     = false
}

variable "enable_monitoring" {
  description = "Enable advanced monitoring stack"
  type        = bool
  default     = true
}

variable "enable_backup" {
  description = "Enable backup services"
  type        = bool
  default     = false
}

# ===================================================================
# VPC Configuration
# ===================================================================

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones_count" {
  description = "Number of availability zones"
  type        = number
  default     = 3
}

variable "private_subnets_count" {
  description = "Number of private subnets per AZ"
  type        = number
  default     = 2
}

variable "public_subnets_count" {
  description = "Number of public subnets per AZ"
  type        = number
  default     = 1
}

variable "database_subnets_count" {
  description = "Number of database subnets per AZ"
  type        = number
  default     = 1
}

variable "nat_gateway_count" {
  description = "Number of NAT gateways"
  type        = number
  default     = 3
}

variable "enable_nat_gateway" {
  description = "Enable NAT gateway"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT gateway for all private subnets"
  type        = bool
  default     = false
}

variable "one_nat_gateway_per_az" {
  description = "One NAT gateway per availability zone"
  type        = bool
  default     = true
}

# ===================================================================
# EKS Cluster Configurations
# ===================================================================

variable "base_cluster_config" {
  description = "Base cluster configuration"
  type = object({
    version            = string
    enable_fargate     = bool
    enable_managed_nodes = bool
    
    fargate_profiles = optional(map(object({
      namespace_selectors = list(string)
      label_selectors    = optional(map(string), {})
      subnet_type        = optional(string, "private")
    })), {})
    
    managed_node_groups = optional(map(object({
      instance_types = list(string)
      capacity_type  = optional(string, "SPOT")
      min_size      = optional(number, 1)
      max_size      = optional(number, 2)
      desired_size  = optional(number, 1)
      disk_size     = optional(number, 100)
      disk_type     = optional(string, "gp3")
      ami_type      = optional(string, "BOTTLEROCKET_x86_64")
      labels        = optional(map(string), {})
      
      mixed_instances_policy = optional(object({
        instances_distribution = optional(object({
          on_demand_percentage     = optional(number, 40)
          spot_allocation_strategy = optional(string, "price-capacity-optimized")
          spot_instance_pools      = optional(number, 2)
        }), {})
      }), null)
    })), {})
  })
  
  default = {
    version            = "1.33"
    enable_fargate     = true
    enable_managed_nodes = true
    
    fargate_profiles = {
      base_data_ingestion = {
        namespace_selectors = ["base-data-ingestion"]
        label_selectors    = {}
        subnet_type        = "private"
      }
    }
    
    managed_node_groups = {
      base_apps = {
        instance_types = ["m7i.2xlarge", "m7i.4xlarge"]
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
}

variable "platform_cluster_config" {
  description = "Platform cluster configuration"
  type = object({
    version            = string
    enable_fargate     = bool
    enable_managed_nodes = bool
    
    fargate_profiles = optional(map(object({
      namespace_selectors = list(string)
      label_selectors    = optional(map(string), {})
      subnet_type        = optional(string, "private")
    })), {})
    
    managed_node_groups = optional(map(object({
      instance_types = list(string)
      capacity_type  = optional(string, "MIXED")
      min_size      = optional(number, 1)
      max_size      = optional(number, 2)
      desired_size  = optional(number, 1)
      disk_size     = optional(number, 200)
      disk_type     = optional(string, "gp3")
      ami_type      = optional(string, "BOTTLEROCKET_x86_64")
      labels        = optional(map(string), {})
      
      mixed_instances_policy = optional(object({
        instances_distribution = optional(object({
          on_demand_percentage     = optional(number, 40)
          spot_allocation_strategy = optional(string, "price-capacity-optimized")
        }), {})
      }), null)
    })), {})
  })
  
  default = {
    version            = "1.33"
    enable_fargate     = true
    enable_managed_nodes = true
    
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
      platform_services = {
        instance_types = ["m7i.2xlarge", "m7i.4xlarge"]
        capacity_type  = "MIXED"
        min_size      = 1
        max_size      = 2
        desired_size  = 1
        disk_size     = 200
        disk_type     = "gp3"
        ami_type      = "BOTTLEROCKET_x86_64"
        
        labels = {
          NodeGroup    = "platform-services"
          Environment  = "dev"
          WorkloadType = "platform-services"
        }
        
        mixed_instances_policy = {
          instances_distribution = {
            on_demand_percentage     = 40
            spot_allocation_strategy = "price-capacity-optimized"
          }
        }
      }
    }
  }
}

# ===================================================================
# EKS Addons and IRSA
# ===================================================================

variable "cluster_addons" {
  description = "EKS cluster addons"
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
  }
}

variable "enable_irsa" {
  description = "Enable IAM roles for service accounts"
  type        = bool
  default     = true
}

variable "irsa_roles" {
  description = "IRSA roles configuration"
  type = map(object({
    policy_arns      = list(string)
    namespaces       = list(string)
    service_accounts = list(string)
  }))
  
  default = {
    argocd = {
      policy_arns = [
        "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
      ]
      namespaces       = ["argocd"]
      service_accounts = ["argocd-server", "argocd-application-controller"]
    }
    airflow = {
      policy_arns = [
        "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
      ]
      namespaces       = ["airflow"]
      service_accounts = ["airflow-scheduler", "airflow-webserver"]
    }
  }
}

# ===================================================================
# Storage Configuration
# ===================================================================

variable "data_storage_config" {
  description = "Data storage configuration"
  type = object({
    s3_buckets = optional(map(object({
      name                    = string
      versioning             = optional(bool, true)
      lifecycle_rules        = optional(bool, true)
      glacier_transition_days = optional(number, 30)
    })), {})
  })
  
  default = {
    s3_buckets = {
      raw_data = {
        name                    = "raw-data-lake"
        versioning             = true
        lifecycle_rules        = true
        glacier_transition_days = 30
      }
    }
  }
}

variable "database_config" {
  description = "Database configuration"
  type = object({
    create_db_subnet_group = optional(bool, true)
    databases = optional(map(object({
      engine               = string
      engine_version       = string
      instance_class       = string
      allocated_storage    = number
      storage_encrypted    = optional(bool, true)
      multi_az            = optional(bool, false)
      publicly_accessible = optional(bool, false)
    })), {})
  })
  
  default = {
    create_db_subnet_group = true
    databases = {}
  }
}

variable "service_roles" {
  description = "Additional service roles"
  type = map(object({
    policy_arns = list(string)
    description = string
  }))
  
  default = {}
}

# ===================================================================
# Common Tags
# ===================================================================

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  
  default = {
    Project        = "base-app-layer"
    Environment    = "dev"
    ManagedBy      = "terraform"
    Owner          = "platform-engineering"
    CloudProvider  = "aws"
    Architecture   = "minimal-microservices"
    CostOptimized  = "true"
    AutoShutdown   = "enabled"
  }
}

# ===================================================================
# Crossplane Configuration
# ===================================================================
variable "enable_crossplane" {
  description = "Enable Crossplane infrastructure as code platform"
  type        = bool
  default     = true
}

variable "crossplane_namespace" {
  description = "Kubernetes namespace for Crossplane"
  type        = string
  default     = "crossplane-system"
}

variable "crossplane_version" {
  description = "Crossplane Helm chart version"
  type        = string
  default     = "1.17.1"
}

variable "enable_crossplane_aws_provider" {
  description = "Enable AWS provider for Crossplane"
  type        = bool
  default     = true
}

variable "enable_crossplane_compositions" {
  description = "Enable default Crossplane compositions"
  type        = bool
  default     = true
}

variable "enable_crossplane_metrics" {
  description = "Enable Crossplane metrics collection"
  type        = bool
  default     = true
}

variable "crossplane_aws_credentials_source" {
  description = "Source of AWS credentials for Crossplane provider"
  type        = string
  default     = "IRSA"
}

variable "crossplane_create_irsa_role" {
  description = "Create IRSA role for Crossplane"
  type        = bool
  default     = true
}
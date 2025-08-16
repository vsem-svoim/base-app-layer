# Project Configuration
variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones_count" {
  description = "Number of availability zones to use"
  type        = number
  default     = 3
  validation {
    condition     = var.availability_zones_count >= 2 && var.availability_zones_count <= 6
    error_message = "Availability zones count must be between 2 and 6."
  }
}

variable "private_subnets_count" {
  description = "Number of private subnets per AZ"
  type        = number
  default     = 1
}

variable "public_subnets_count" {
  description = "Number of public subnets per AZ"
  type        = number
  default     = 1
}

variable "nat_gateway_count" {
  description = "Number of NAT gateways (0 = no NAT, 1 = single NAT, 2+ = multiple NAT)"
  type        = number
  default     = 1
  validation {
    condition     = var.nat_gateway_count >= 0
    error_message = "NAT gateway count must be 0 or greater."
  }
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
  description = "Use one NAT gateway per availability zone"
  type        = bool
  default     = true
}

# BASE Layer Cluster Configuration
variable "base_cluster_enabled" {
  description = "Enable BASE layer cluster"
  type        = bool
  default     = true
}

variable "base_cluster_config" {
  description = "Configuration for BASE layer cluster"
  type = object({
    name               = string
    version            = string
    enable_fargate     = bool
    enable_managed_nodes = bool
    fargate_profiles   = map(object({
      namespace_selectors = list(string)
      label_selectors    = map(string)
    }))
    managed_node_groups = map(object({
      instance_types = list(string)
      capacity_type  = string
      min_size      = number
      max_size      = number
      desired_size  = number
      disk_size     = number
      disk_type     = string
      ami_type      = string
      labels        = map(string)
      taints = map(object({
        key    = string
        value  = string
        effect = string
      }))
    }))
  })
  default = {
    name               = "base-layer"
    version            = "1.33"
    enable_fargate     = true
    enable_managed_nodes = true
    fargate_profiles = {
      base_components = {
        namespace_selectors = ["base-*"]
        label_selectors    = {}
      }
    }
    managed_node_groups = {
      base_layer_nodes = {
        instance_types = ["t3.medium", "t3.large"]
        capacity_type  = "ON_DEMAND"
        min_size      = 1
        max_size      = 10
        desired_size  = 3
        disk_size     = 50
        disk_type     = "gp3"
        ami_type      = "BOTTLEROCKET_x86_64"
        labels = {
          NodeGroup   = "base-layer"
          Environment = "dev"
        }
        taints = {
          base_layer = {
            key    = "base-layer"
            value  = "true"
            effect = "NO_SCHEDULE"
          }
        }
      }
    }
  }
}

# Platform Services Cluster Configuration
variable "platform_cluster_enabled" {
  description = "Enable platform services cluster"
  type        = bool
  default     = true
}

variable "platform_cluster_config" {
  description = "Configuration for platform services cluster"
  type = object({
    name               = string
    version            = string
    enable_fargate     = bool
    enable_managed_nodes = bool
    fargate_profiles   = map(object({
      namespace_selectors = list(string)
      label_selectors    = map(string)
    }))
    managed_node_groups = map(object({
      instance_types = list(string)
      capacity_type  = string
      min_size      = number
      max_size      = number
      desired_size  = number
      disk_size     = number
      disk_type     = string
      ami_type      = string
      labels        = map(string)
      taints = map(object({
        key    = string
        value  = string
        effect = string
      }))
    }))
  })
  default = {
    name               = "platform-services"
    version            = "1.33"
    enable_fargate     = true
    enable_managed_nodes = true
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
        namespace_selectors = ["ml-*"]
        label_selectors    = {}
      }
    }
    managed_node_groups = {
      platform_nodes = {
        instance_types = ["t3.large", "t3.xlarge"]
        capacity_type  = "ON_DEMAND"
        min_size      = 1
        max_size      = 10
        desired_size  = 3
        disk_size     = 100
        disk_type     = "gp3"
        ami_type      = "BOTTLEROCKET_x86_64"
        labels = {
          NodeGroup   = "platform-services"
          Environment = "dev"
        }
        taints = {}
      }
      ml_nodes = {
        instance_types = ["m5.large", "m5.xlarge"]
        capacity_type  = "SPOT"
        min_size      = 0
        max_size      = 20
        desired_size  = 2
        disk_size     = 100
        disk_type     = "gp3"
        ami_type      = "BOTTLEROCKET_x86_64"
        labels = {
          NodeGroup   = "ml-workloads"
          Environment = "dev"
        }
        taints = {
          ml_workload = {
            key    = "ml-workload"
            value  = "true"
            effect = "NO_SCHEDULE"
          }
        }
      }
    }
  }
}

# EKS Add-ons Configuration
variable "cluster_addons" {
  description = "EKS cluster add-ons configuration"
  type = map(object({
    most_recent    = bool
    addon_version  = string
    configuration_values = string
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
      most_recent    = true
      addon_version = ""
      configuration_values = ""
    }
    aws-ebs-csi-driver = {
      most_recent           = true
      addon_version        = ""
      configuration_values = ""
    }
  }
}

# IAM Configuration
variable "enable_irsa" {
  description = "Enable IAM Roles for Service Accounts"
  type        = bool
  default     = true
}

variable "irsa_roles" {
  description = "IRSA roles configuration"
  type = map(object({
    policy_arns = list(string)
    namespaces  = list(string)
    service_accounts = list(string)
  }))
  default = {
    crossplane = {
      policy_arns      = ["arn:aws:iam::aws:policy/AdministratorAccess"]
      namespaces       = ["crossplane-system"]
      service_accounts = ["crossplane"]
    }
    argocd = {
      policy_arns      = ["arn:aws:iam::aws:policy/AdministratorAccess"]
      namespaces       = ["argocd"]
      service_accounts = ["argocd-server", "argocd-application-controller"]
    }
  }
}

# Tags
variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

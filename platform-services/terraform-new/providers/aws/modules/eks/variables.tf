# ===================================================================
# EKS Module Variables
# ===================================================================

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.33"
}

variable "cluster_config" {
  description = "EKS cluster configuration"
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
}

variable "vpc_id" {
  description = "VPC ID where EKS cluster will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for EKS cluster"
  type        = list(string)
}

variable "control_plane_subnet_ids" {
  description = "List of subnet IDs for EKS control plane"
  type        = list(string)
}

variable "cluster_addons" {
  description = "EKS cluster addons"
  type = map(object({
    most_recent           = optional(bool, true)
    addon_version        = optional(string, "")
    configuration_values = optional(string, "")
  }))
  default = {}
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
  default = {}
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
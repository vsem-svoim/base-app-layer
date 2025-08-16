# Basic Configuration Variables
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

# VPC Configuration Variables
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "availability_zones_count" {
  description = "Number of availability zones to use"
  type        = number
}

variable "private_subnets_count" {
  description = "Number of private subnets per AZ"
  type        = number
}

variable "public_subnets_count" {
  description = "Number of public subnets per AZ"
  type        = number
}

variable "nat_gateway_count" {
  description = "Number of NAT gateways"
  type        = number
}

variable "enable_nat_gateway" {
  description = "Enable NAT gateway"
  type        = bool
}

variable "single_nat_gateway" {
  description = "Use single NAT gateway for all private subnets"
  type        = bool
}

variable "one_nat_gateway_per_az" {
  description = "Use one NAT gateway per availability zone"
  type        = bool
}

# Cluster Configuration Variables
variable "base_cluster_enabled" {
  description = "Enable BASE layer cluster"
  type        = bool
}

variable "platform_cluster_enabled" {
  description = "Enable platform services cluster"
  type        = bool
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
}

variable "cluster_addons" {
  description = "EKS cluster add-ons configuration"
  type = map(object({
    most_recent    = bool
    addon_version  = string
    configuration_values = string
  }))
}

variable "enable_irsa" {
  description = "Enable IAM Roles for Service Accounts"
  type        = bool
}

variable "irsa_roles" {
  description = "IRSA roles configuration"
  type = map(object({
    policy_arns = list(string)
    namespaces  = list(string)
    service_accounts = list(string)
  }))
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
}

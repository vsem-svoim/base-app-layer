# ===================================================================
# Karpenter Module Variables
# ===================================================================

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS cluster endpoint"
  type        = string
}

variable "enable_karpenter" {
  description = "Enable Karpenter node provisioning"
  type        = bool
  default     = true
}

variable "karpenter_version" {
  description = "Karpenter Helm chart version"
  type        = string
  default     = "v0.37.0"
}

variable "karpenter_irsa_role_arn" {
  description = "Karpenter IRSA role ARN"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for Karpenter nodes"
  type        = list(string)
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
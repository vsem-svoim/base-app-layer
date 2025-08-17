# ===================================================================
# IAM Module Variables
# ===================================================================

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "service_roles" {
  description = "Additional service roles"
  type = map(object({
    policy_arns = list(string)
    description = string
  }))
  default = {}
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
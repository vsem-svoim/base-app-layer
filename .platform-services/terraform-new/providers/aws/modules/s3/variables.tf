# ===================================================================
# S3 Module Variables
# ===================================================================

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

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
    s3_buckets = {}
  }
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
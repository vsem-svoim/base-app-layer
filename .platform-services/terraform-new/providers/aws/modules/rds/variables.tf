# ===================================================================
# RDS Module Variables
# ===================================================================

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where RDS instances will be created"
  type        = string
}

variable "database_subnets" {
  description = "List of subnet IDs for database subnet group"
  type        = list(string)
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

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
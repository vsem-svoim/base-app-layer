# ===================================================================
# ACM Module Variables
# ===================================================================

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "platform_domain" {
  description = "Primary domain for the SSL certificate (e.g., fin.vsem-svoim.com)"
  type        = string
}

variable "base_domain" {
  description = "Base domain name (e.g., vsem-svoim.com)"
  type        = string
}

variable "additional_domains" {
  description = "Additional domains to include in certificate (SANs)"
  type        = list(string)
  default     = []
}

variable "import_existing_wildcard" {
  description = "Import existing wildcard certificate instead of creating new"
  type        = bool
  default     = false
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
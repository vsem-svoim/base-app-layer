# ===================================================================
# Route 53 Module Variables
# ===================================================================

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "domain_name" {
  description = "Main domain name (e.g., vsem-svoim.com)"
  type        = string
}

variable "platform_subdomain" {
  description = "Platform subdomain FQDN (e.g., fin.vsem-svoim.com)"
  type        = string
}

variable "alb_dns_name" {
  description = "ALB DNS name for A record alias"
  type        = string
  default     = ""
}

variable "alb_zone_id" {
  description = "ALB hosted zone ID for A record alias"
  type        = string
  default     = "Z35SXDOTRQ7X7K" # US East 1 ALB zone ID
}

variable "certificate_validation_records" {
  description = "Certificate validation DNS records"
  type = map(object({
    name  = string
    type  = string
    value = string
  }))
  default = {}
}

variable "enable_health_checks" {
  description = "Enable Route 53 health checks"
  type        = bool
  default     = true
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
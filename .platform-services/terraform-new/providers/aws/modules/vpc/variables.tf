# ===================================================================
# VPC Module Variables
# ===================================================================

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
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

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
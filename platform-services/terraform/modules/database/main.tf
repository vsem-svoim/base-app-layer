# Provider-agnostic database module
variable "database_name" {
  description = "Name of the database"
  type        = string
}

variable "instance_class" {
  description = "Database instance class"
  type        = string
  default     = "medium"
}

variable "allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 100
}

variable "provider_type" {
  description = "Cloud provider type"
  type        = string
}

# ===================================================================
# Crossplane Module Variables
# ===================================================================

variable "enable_crossplane" {
  description = "Enable Crossplane installation"
  type        = bool
  default     = true
}

variable "crossplane_version" {
  description = "Crossplane Helm chart version"
  type        = string
  default     = "1.17.1"
}

variable "crossplane_namespace" {
  description = "Kubernetes namespace for Crossplane"
  type        = string
  default     = "crossplane-system"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS cluster endpoint for dependency"
  type        = string
}

variable "enable_metrics" {
  description = "Enable Crossplane metrics"
  type        = bool
  default     = true
}

variable "crossplane_resources" {
  description = "Resource limits for Crossplane pods"
  type = object({
    limits = optional(object({
      cpu    = optional(string, "100m")
      memory = optional(string, "512Mi")
    }), {})
    requests = optional(object({
      cpu    = optional(string, "100m")
      memory = optional(string, "256Mi")
    }), {})
  })
  default = {}
}

variable "enable_aws_provider" {
  description = "Enable AWS provider for Crossplane"
  type        = bool
  default     = true
}

variable "aws_provider_package" {
  description = "Crossplane AWS provider package"
  type        = string
  default     = "xpkg.upbound.io/crossplane-contrib/provider-aws:v0.46.0"
}

variable "provider_packages" {
  description = "List of provider packages to install"
  type        = list(string)
  default     = []
}

variable "configuration_packages" {
  description = "List of configuration packages to install"
  type        = list(string)
  default     = []
}

variable "aws_credentials_source" {
  description = "Source of AWS credentials for Crossplane provider"
  type        = string
  default     = "IRSA"
  validation {
    condition     = contains(["Secret", "IRSA", "Environment"], var.aws_credentials_source)
    error_message = "aws_credentials_source must be one of: Secret, IRSA, Environment"
  }
}

variable "aws_credentials_secret" {
  description = "Name of Kubernetes secret containing AWS credentials"
  type        = string
  default     = "aws-secret"
}

variable "enable_compositions" {
  description = "Enable default Crossplane compositions"
  type        = bool
  default     = true
}

variable "create_irsa_role" {
  description = "Create IRSA role for Crossplane"
  type        = bool
  default     = true
}

variable "oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA"
  type        = string
  default     = ""
}

variable "oidc_issuer" {
  description = "OIDC issuer URL for IRSA"
  type        = string
  default     = ""
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}
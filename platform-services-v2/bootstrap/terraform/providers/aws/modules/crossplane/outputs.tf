# ===================================================================
# Crossplane Module Outputs
# ===================================================================

output "crossplane_namespace" {
  description = "Crossplane installation namespace"
  value       = var.crossplane_namespace
}

output "crossplane_release_name" {
  description = "Crossplane Helm release name"
  value       = var.enable_crossplane ? helm_release.crossplane[0].name : null
}

output "crossplane_release_version" {
  description = "Crossplane Helm release version"
  value       = var.enable_crossplane ? helm_release.crossplane[0].version : null
}

output "aws_provider_installed" {
  description = "Whether AWS provider is installed"
  value       = var.enable_crossplane && var.enable_aws_provider
}

output "crossplane_irsa_role_arn" {
  description = "ARN of the Crossplane IRSA role"
  value       = var.enable_crossplane && var.create_irsa_role ? aws_iam_role.crossplane_role[0].arn : null
}

output "crossplane_service_account" {
  description = "Crossplane service account name"
  value       = var.enable_crossplane && var.create_irsa_role ? kubernetes_service_account.crossplane[0].metadata[0].name : null
}

output "compositions_enabled" {
  description = "Whether default compositions are enabled"
  value       = var.enable_crossplane && var.enable_compositions
}
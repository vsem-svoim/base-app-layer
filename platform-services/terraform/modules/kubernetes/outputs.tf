# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnets
}

output "nat_gateway_ids" {
  description = "IDs of the NAT gateways"
  value       = module.vpc.natgw_ids
}

# BASE Layer Cluster Outputs
output "base_cluster_enabled" {
  description = "Whether BASE layer cluster is enabled"
  value       = var.base_cluster_enabled
}

output "base_cluster_id" {
  description = "BASE layer EKS cluster ID"
  value       = var.base_cluster_enabled ? module.base_layer_eks[0].cluster_id : null
}

output "base_cluster_arn" {
  description = "BASE layer EKS cluster ARN"
  value       = var.base_cluster_enabled ? module.base_layer_eks[0].cluster_arn : null
}

output "base_cluster_endpoint" {
  description = "Endpoint for BASE layer EKS control plane"
  value       = var.base_cluster_enabled ? module.base_layer_eks[0].cluster_endpoint : null
}

output "base_cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data for BASE layer cluster"
  value       = var.base_cluster_enabled ? module.base_layer_eks[0].cluster_certificate_authority_data : null
  sensitive   = true
}

output "base_cluster_name" {
  description = "BASE layer cluster name"
  value       = var.base_cluster_enabled ? local.base_cluster_name : null
}

output "base_cluster_version" {
  description = "BASE layer cluster Kubernetes version"
  value       = var.base_cluster_enabled ? module.base_layer_eks[0].cluster_version : null
}

# Platform Services Cluster Outputs
output "platform_cluster_enabled" {
  description = "Whether platform services cluster is enabled"
  value       = var.platform_cluster_enabled
}

output "platform_cluster_id" {
  description = "Platform services EKS cluster ID"
  value       = var.platform_cluster_enabled ? module.platform_services_eks[0].cluster_id : null
}

output "platform_cluster_arn" {
  description = "Platform services EKS cluster ARN"
  value       = var.platform_cluster_enabled ? module.platform_services_eks[0].cluster_arn : null
}

output "platform_cluster_endpoint" {
  description = "Endpoint for platform services EKS control plane"
  value       = var.platform_cluster_enabled ? module.platform_services_eks[0].cluster_endpoint : null
}

output "platform_cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data for platform services cluster"
  value       = var.platform_cluster_enabled ? module.platform_services_eks[0].cluster_certificate_authority_data : null
  sensitive   = true
}

output "platform_cluster_name" {
  description = "Platform services cluster name"
  value       = var.platform_cluster_enabled ? local.platform_cluster_name : null
}

output "platform_cluster_version" {
  description = "Platform services cluster Kubernetes version"
  value       = var.platform_cluster_enabled ? module.platform_services_eks[0].cluster_version : null
}

# IRSA Role ARNs
output "irsa_role_arns" {
  description = "ARNs of the IRSA roles"
  value = {
    for role_name, role in module.irsa_roles : role_name => role.iam_role_arn
  }
}

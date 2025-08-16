# ===================================================================
# Infrastructure Outputs
# ===================================================================

# VPC Information
output "vpc_info" {
  description = "VPC configuration details"
  value = {
    vpc_id              = module.multi_cluster_eks.vpc_id
    vpc_cidr            = module.multi_cluster_eks.vpc_cidr_block
    private_subnet_ids  = module.multi_cluster_eks.private_subnet_ids
    public_subnet_ids   = module.multi_cluster_eks.public_subnet_ids
    nat_gateway_ids     = module.multi_cluster_eks.nat_gateway_ids
  }
}

# BASE Layer Cluster Outputs
output "base_cluster_info" {
  description = "BASE layer cluster information"
  value = module.multi_cluster_eks.base_cluster_enabled ? {
    enabled                = module.multi_cluster_eks.base_cluster_enabled
    cluster_id            = module.multi_cluster_eks.base_cluster_id
    cluster_name          = module.multi_cluster_eks.base_cluster_name
    cluster_endpoint      = module.multi_cluster_eks.base_cluster_endpoint
    cluster_version       = module.multi_cluster_eks.base_cluster_version
  } : null
}

output "base_cluster_auth" {
  description = "BASE layer cluster authentication data"
  value = module.multi_cluster_eks.base_cluster_enabled ? {
    certificate_authority_data = module.multi_cluster_eks.base_cluster_certificate_authority_data
  } : null
  sensitive = true
}

# Platform Services Cluster Outputs
output "platform_cluster_info" {
  description = "Platform services cluster information"
  value = module.multi_cluster_eks.platform_cluster_enabled ? {
    enabled                = module.multi_cluster_eks.platform_cluster_enabled
    cluster_id            = module.multi_cluster_eks.platform_cluster_id
    cluster_name          = module.multi_cluster_eks.platform_cluster_name
    cluster_endpoint      = module.multi_cluster_eks.platform_cluster_endpoint
    cluster_version       = module.multi_cluster_eks.platform_cluster_version
  } : null
}

output "platform_cluster_auth" {
  description = "Platform services cluster authentication data"
  value = module.multi_cluster_eks.platform_cluster_enabled ? {
    certificate_authority_data = module.multi_cluster_eks.platform_cluster_certificate_authority_data
  } : null
  sensitive = true
}

# IRSA Role ARNs
output "irsa_role_arns" {
  description = "ARNs of IAM roles for service accounts"
  value       = module.multi_cluster_eks.irsa_role_arns
}

# Kubectl Commands for Cluster Access
output "kubectl_commands" {
  description = "Commands to configure kubectl access"
  value = {
    base_cluster = module.multi_cluster_eks.base_cluster_enabled ? "aws eks update-kubeconfig --region ${var.region} --name ${module.multi_cluster_eks.base_cluster_name} --alias base-layer" : null
    platform_cluster = module.multi_cluster_eks.platform_cluster_enabled ? "aws eks update-kubeconfig --region ${var.region} --name ${module.multi_cluster_eks.platform_cluster_name} --alias platform-services" : null
  }
}

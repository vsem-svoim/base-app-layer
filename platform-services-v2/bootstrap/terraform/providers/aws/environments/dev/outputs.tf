# ===================================================================
# AWS Dev Environment Outputs
# ===================================================================

# ===================================================================
# VPC Outputs
# ===================================================================
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnets" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

output "database_subnets" {
  description = "List of IDs of database subnets"
  value       = module.vpc.database_subnets
}

output "nat_gateway_ips" {
  description = "List of public IPs of the NAT Gateways"
  value       = module.vpc.nat_gateway_public_ips
}

# ===================================================================
# EKS Base Cluster Outputs
# ===================================================================
output "base_cluster_id" {
  description = "The name/id of the base EKS cluster"
  value       = var.base_cluster_enabled ? module.eks_base_cluster[0].cluster_id : null
}

output "base_cluster_name" {
  description = "The name of the base EKS cluster"
  value       = var.base_cluster_enabled ? module.eks_base_cluster[0].cluster_name : null
}

output "base_cluster_endpoint" {
  description = "Endpoint for base EKS control plane"
  value       = var.base_cluster_enabled ? module.eks_base_cluster[0].cluster_endpoint : null
}

output "base_cluster_version" {
  description = "The Kubernetes version for the base cluster"
  value       = var.base_cluster_enabled ? module.eks_base_cluster[0].cluster_version : null
}

output "base_cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data for base cluster"
  value       = var.base_cluster_enabled ? module.eks_base_cluster[0].cluster_certificate_authority_data : null
  sensitive   = true
}

output "base_cluster_oidc_issuer_url" {
  description = "The URL on the base EKS cluster OIDC Issuer"
  value       = var.base_cluster_enabled ? module.eks_base_cluster[0].cluster_oidc_issuer_url : null
}

# ===================================================================
# EKS Platform Cluster Outputs
# ===================================================================
output "platform_cluster_id" {
  description = "The name/id of the platform EKS cluster"
  value       = var.platform_cluster_enabled ? module.eks_platform_cluster[0].cluster_id : null
}

output "platform_cluster_name" {
  description = "The name of the platform EKS cluster"
  value       = var.platform_cluster_enabled ? module.eks_platform_cluster[0].cluster_name : null
}

output "platform_cluster_endpoint" {
  description = "Endpoint for platform EKS control plane"
  value       = var.platform_cluster_enabled ? module.eks_platform_cluster[0].cluster_endpoint : null
}

output "platform_cluster_version" {
  description = "The Kubernetes version for the platform cluster"
  value       = var.platform_cluster_enabled ? module.eks_platform_cluster[0].cluster_version : null
}

output "platform_cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data for platform cluster"
  value       = var.platform_cluster_enabled ? module.eks_platform_cluster[0].cluster_certificate_authority_data : null
  sensitive   = true
}

output "platform_cluster_oidc_issuer_url" {
  description = "The URL on the platform EKS cluster OIDC Issuer"
  value       = var.platform_cluster_enabled ? module.eks_platform_cluster[0].cluster_oidc_issuer_url : null
}

# ===================================================================
# S3 Storage Outputs (if enabled)
# ===================================================================
output "s3_bucket_ids" {
  description = "Map of S3 bucket IDs"
  value       = var.enable_data_storage ? module.s3_data_storage[0].bucket_ids : {}
}

output "s3_bucket_arns" {
  description = "Map of S3 bucket ARNs"
  value       = var.enable_data_storage ? module.s3_data_storage[0].bucket_arns : {}
}

# ===================================================================
# RDS Database Outputs (if enabled)
# ===================================================================
output "db_instance_endpoints" {
  description = "Map of RDS instance endpoints"
  value       = var.enable_databases ? module.rds_databases[0].db_instance_endpoints : {}
}

output "db_instance_ports" {
  description = "Map of RDS instance ports"
  value       = var.enable_databases ? module.rds_databases[0].db_instance_ports : {}
}

output "db_secret_arns" {
  description = "Map of database credential secret ARNs"
  value       = var.enable_databases ? module.rds_databases[0].secret_arns : {}
  sensitive   = true
}

# ===================================================================
# IAM Service Roles Outputs (if enabled)
# ===================================================================
output "service_role_arns" {
  description = "Map of service role ARNs"
  value       = var.enable_service_iam ? module.iam_service_roles[0].service_role_arns : {}
}

output "data_processing_role_arn" {
  description = "ARN of the data processing role"
  value       = var.enable_service_iam ? module.iam_service_roles[0].data_processing_role_arn : null
}

# ===================================================================
# SSL Certificate Outputs
# ===================================================================

output "ssl_certificate_arn" {
  description = "SSL certificate ARN"
  value       = var.enable_ssl_certificates ? module.acm_certificates[0].certificate_arn : null
}

output "ssl_certificate_domain" {
  description = "SSL certificate domain"
  value       = var.enable_ssl_certificates ? module.acm_certificates[0].certificate_domain : null
}

# ===================================================================
# DNS Outputs
# ===================================================================

output "hosted_zone_id" {
  description = "Route 53 hosted zone ID"
  value       = var.enable_dns_management ? module.route53_dns[0].hosted_zone_id : null
}

output "platform_fqdn" {
  description = "Platform FQDN"
  value       = var.enable_dns_management ? module.route53_dns[0].platform_fqdn : var.platform_domain
}

output "platform_url" {
  description = "Platform HTTPS URL"
  value       = "https://${var.platform_domain}"
}

# ===================================================================
# Kubectl Commands for Cluster Access
# ===================================================================
output "kubectl_config_base_cluster" {
  description = "kubectl config command for base cluster"
  value       = var.base_cluster_enabled ? "aws eks update-kubeconfig --region ${var.region} --name ${module.eks_base_cluster[0].cluster_name} --profile ${var.aws_profile}" : null
}

output "kubectl_config_platform_cluster" {
  description = "kubectl config command for platform cluster"
  value       = var.platform_cluster_enabled ? "aws eks update-kubeconfig --region ${var.region} --name ${module.eks_platform_cluster[0].cluster_name} --profile ${var.aws_profile}" : null
}

# ===================================================================
# Deployment Summary
# ===================================================================
output "deployment_summary" {
  description = "Summary of deployed resources"
  value = {
    region                      = var.region
    environment                 = var.environment
    project_name               = var.project_name
    vpc_id                     = module.vpc.vpc_id
    base_cluster_enabled       = var.base_cluster_enabled
    platform_cluster_enabled  = var.platform_cluster_enabled
    data_storage_enabled       = var.enable_data_storage
    databases_enabled          = var.enable_databases
    service_iam_enabled        = var.enable_service_iam
    ssl_certificates_enabled   = var.enable_ssl_certificates
    dns_management_enabled     = var.enable_dns_management
    monitoring_enabled         = var.enable_monitoring
    backup_enabled             = var.enable_backup
    platform_access = {
      domain           = var.platform_domain
      ssl_certificate  = var.enable_ssl_certificates ? module.acm_certificates[0].certificate_arn : "none"
      alb_dns_name     = var.alb_dns_name
      platform_url     = "https://${var.platform_domain}"
    }
  }
}
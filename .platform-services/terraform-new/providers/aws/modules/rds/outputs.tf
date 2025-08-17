# ===================================================================
# RDS Module Outputs
# ===================================================================

output "db_instance_ids" {
  description = "Map of RDS instance IDs"
  value = {
    for k, v in aws_db_instance.main : k => v.id
  }
}

output "db_instance_arns" {
  description = "Map of RDS instance ARNs"
  value = {
    for k, v in aws_db_instance.main : k => v.arn
  }
}

output "db_instance_endpoints" {
  description = "Map of RDS instance endpoints"
  value = {
    for k, v in aws_db_instance.main : k => v.endpoint
  }
}

output "db_instance_ports" {
  description = "Map of RDS instance ports"
  value = {
    for k, v in aws_db_instance.main : k => v.port
  }
}

output "db_instance_hosted_zone_ids" {
  description = "Map of RDS instance hosted zone IDs"
  value = {
    for k, v in aws_db_instance.main : k => v.hosted_zone_id
  }
}

output "db_subnet_group_id" {
  description = "ID of the database subnet group"
  value       = var.database_config.create_db_subnet_group ? aws_db_subnet_group.main[0].id : null
}

output "db_subnet_group_arn" {
  description = "ARN of the database subnet group"
  value       = var.database_config.create_db_subnet_group ? aws_db_subnet_group.main[0].arn : null
}

output "db_security_group_id" {
  description = "ID of the database security group"
  value       = aws_security_group.rds.id
}

output "db_security_group_arn" {
  description = "ARN of the database security group"
  value       = aws_security_group.rds.arn
}

output "kms_key_id" {
  description = "ID of the KMS key used for RDS encryption"
  value       = aws_kms_key.rds.key_id
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for RDS encryption"
  value       = aws_kms_key.rds.arn
}

output "secret_arns" {
  description = "Map of Secrets Manager secret ARNs for database credentials"
  value = {
    for k, v in aws_secretsmanager_secret.db_credentials : k => v.arn
  }
}

output "secret_names" {
  description = "Map of Secrets Manager secret names for database credentials"
  value = {
    for k, v in aws_secretsmanager_secret.db_credentials : k => v.name
  }
}

output "monitoring_role_arn" {
  description = "ARN of the enhanced monitoring IAM role"
  value       = aws_iam_role.rds_enhanced_monitoring.arn
}
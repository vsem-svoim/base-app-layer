# ===================================================================
# RDS Module for Database Infrastructure
# ===================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# ===================================================================
# Data Sources
# ===================================================================
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ===================================================================
# Local Values
# ===================================================================
locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

# ===================================================================
# Random Password for Databases
# ===================================================================
resource "random_password" "db_password" {
  for_each = var.database_config.databases

  length  = 16
  special = true
}

# ===================================================================
# KMS Key for RDS Encryption
# ===================================================================
resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccess"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${local.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "EnableRDSService"
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:CreateGrant"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "rds.${local.region}.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${var.environment}-rds-key"
    Type    = "kms-key"
    Purpose = "rds-encryption"
  })
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.project_name}-${var.environment}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# ===================================================================
# DB Subnet Group
# ===================================================================
resource "aws_db_subnet_group" "main" {
  count = var.database_config.create_db_subnet_group ? 1 : 0

  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = var.database_subnets

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-db-subnet-group"
    Type = "db-subnet-group"
  })
}

# ===================================================================
# Database Security Group
# ===================================================================
resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-${var.environment}-rds-"
  description = "Security group for RDS databases"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-rds-sg"
    Type = "security-group"
  })
}

# PostgreSQL ingress rule
resource "aws_security_group_rule" "rds_ingress_postgresql" {
  for_each = {
    for k, v in var.database_config.databases : k => v
    if v.engine == "postgres"
  }

  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = ["10.0.0.0/16"]  # VPC CIDR
  security_group_id = aws_security_group.rds.id
  description       = "PostgreSQL access from VPC"
}

# MySQL ingress rule
resource "aws_security_group_rule" "rds_ingress_mysql" {
  for_each = {
    for k, v in var.database_config.databases : k => v
    if v.engine == "mysql"
  }

  type              = "ingress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  cidr_blocks       = ["10.0.0.0/16"]  # VPC CIDR
  security_group_id = aws_security_group.rds.id
  description       = "MySQL access from VPC"
}

# ===================================================================
# RDS Instances
# ===================================================================
resource "aws_db_instance" "main" {
  for_each = var.database_config.databases

  identifier     = "${var.project_name}-${var.environment}-${each.key}"
  engine         = each.value.engine
  engine_version = each.value.engine_version
  instance_class = each.value.instance_class

  allocated_storage     = each.value.allocated_storage
  max_allocated_storage = each.value.allocated_storage * 2
  storage_type          = "gp3"
  storage_encrypted     = each.value.storage_encrypted
  kms_key_id           = each.value.storage_encrypted ? aws_kms_key.rds.arn : null

  db_name  = each.key
  username = "admin"
  password = random_password.db_password[each.key].result

  db_subnet_group_name   = var.database_config.create_db_subnet_group ? aws_db_subnet_group.main[0].name : null
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = each.value.publicly_accessible

  multi_az               = each.value.multi_az
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  # Enhanced monitoring
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_enhanced_monitoring.arn

  # Performance Insights
  performance_insights_enabled = true
  performance_insights_kms_key_id = aws_kms_key.rds.arn

  # Logging
  enabled_cloudwatch_logs_exports = each.value.engine == "postgres" ? ["postgresql"] : ["error", "general", "slow_query"]

  # Deletion protection
  deletion_protection = var.environment == "prod" ? true : false
  skip_final_snapshot = var.environment == "prod" ? false : true
  final_snapshot_identifier = var.environment == "prod" ? "${var.project_name}-${var.environment}-${each.key}-final-snapshot" : null

  tags = merge(var.common_tags, {
    Name     = "${var.project_name}-${var.environment}-${each.key}"
    Type     = "rds-instance"
    Engine   = each.value.engine
    Database = each.key
  })
}

# ===================================================================
# Enhanced Monitoring IAM Role
# ===================================================================
resource "aws_iam_role" "rds_enhanced_monitoring" {
  name_prefix = "${var.project_name}-${var.environment}-rds-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-rds-monitoring-role"
    Type = "iam-role"
  })
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ===================================================================
# Secrets Manager for Database Credentials
# ===================================================================
resource "aws_secretsmanager_secret" "db_credentials" {
  for_each = var.database_config.databases

  name                    = "${var.project_name}/${var.environment}/rds/${each.key}"
  description             = "Database credentials for ${each.key}"
  kms_key_id              = aws_kms_key.rds.arn
  recovery_window_in_days = 7

  tags = merge(var.common_tags, {
    Name     = "${var.project_name}-${var.environment}-${each.key}-credentials"
    Type     = "secret"
    Database = each.key
  })
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  for_each = var.database_config.databases

  secret_id = aws_secretsmanager_secret.db_credentials[each.key].id
  secret_string = jsonencode({
    username = aws_db_instance.main[each.key].username
    password = random_password.db_password[each.key].result
    endpoint = aws_db_instance.main[each.key].endpoint
    port     = aws_db_instance.main[each.key].port
    dbname   = aws_db_instance.main[each.key].db_name
    engine   = aws_db_instance.main[each.key].engine
  })
}

# ===================================================================
# CloudWatch Log Groups
# ===================================================================
resource "aws_cloudwatch_log_group" "rds" {
  for_each = {
    for pair in flatten([
      for db_name, db_config in var.database_config.databases : [
        for log_type in (db_config.engine == "postgres" ? ["postgresql"] : ["error", "general", "slow_query"]) : {
          db_name  = db_name
          log_type = log_type
        }
      ]
    ]) : "${pair.db_name}-${pair.log_type}" => pair
  }

  name              = "/aws/rds/instance/${var.project_name}-${var.environment}-${each.value.db_name}/${each.value.log_type}"
  retention_in_days = 7
  kms_key_id        = aws_kms_key.rds.arn

  tags = merge(var.common_tags, {
    Name     = "${var.project_name}-${var.environment}-${each.value.db_name}-${each.value.log_type}"
    Type     = "log-group"
    Database = each.value.db_name
    LogType  = each.value.log_type
  })
}
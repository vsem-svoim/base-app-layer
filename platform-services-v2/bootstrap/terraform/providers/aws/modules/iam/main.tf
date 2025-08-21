# ===================================================================
# IAM Module for Service Roles
# ===================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ===================================================================
# Data Sources
# ===================================================================
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

# ===================================================================
# Local Values
# ===================================================================
locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  partition  = data.aws_partition.current.partition
}

# ===================================================================
# Service Roles
# ===================================================================
resource "aws_iam_role" "service_roles" {
  for_each = var.service_roles

  name        = "${var.project_name}-${var.environment}-${each.key}-role"
  description = each.value.description

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "ec2.amazonaws.com",
            "ecs-tasks.amazonaws.com",
            "lambda.amazonaws.com"
          ]
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-${each.key}-role"
    Type        = "iam-role"
    ServiceRole = each.key
  })
}

# ===================================================================
# Attach Policies to Service Roles
# ===================================================================
resource "aws_iam_role_policy_attachment" "service_roles" {
  for_each = {
    for pair in flatten([
      for role_name, role_config in var.service_roles : [
        for policy_arn in role_config.policy_arns : {
          role_name   = role_name
          policy_arn  = policy_arn
        }
      ]
    ]) : "${pair.role_name}-${replace(pair.policy_arn, "/[^a-zA-Z0-9]/", "-")}" => pair
  }

  role       = aws_iam_role.service_roles[each.value.role_name].name
  policy_arn = each.value.policy_arn
}

# ===================================================================
# Instance Profiles for EC2
# ===================================================================
resource "aws_iam_instance_profile" "service_roles" {
  for_each = var.service_roles

  name = "${var.project_name}-${var.environment}-${each.key}-profile"
  role = aws_iam_role.service_roles[each.key].name

  tags = merge(var.common_tags, {
    Name        = "${var.project_name}-${var.environment}-${each.key}-profile"
    Type        = "iam-instance-profile"
    ServiceRole = each.key
  })
}

# ===================================================================
# Custom Policies for Data Processing
# ===================================================================

# S3 Data Access Policy
resource "aws_iam_policy" "s3_data_access" {
  name        = "${var.project_name}-${var.environment}-s3-data-access"
  description = "Policy for S3 data access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:DeleteObject",
          "s3:DeleteObjectVersion"
        ]
        Resource = [
          "arn:${local.partition}:s3:::${var.project_name}-*/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:ListBucketVersions",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:${local.partition}:s3:::${var.project_name}-*"
        ]
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-s3-data-access"
    Type = "iam-policy"
  })
}

# Kinesis Data Streams Policy
resource "aws_iam_policy" "kinesis_access" {
  name        = "${var.project_name}-${var.environment}-kinesis-access"
  description = "Policy for Kinesis data streams access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesis:PutRecord",
          "kinesis:PutRecords",
          "kinesis:GetRecords",
          "kinesis:GetShardIterator",
          "kinesis:DescribeStream",
          "kinesis:ListStreams"
        ]
        Resource = [
          "arn:${local.partition}:kinesis:${local.region}:${local.account_id}:stream/${var.project_name}-*"
        ]
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-kinesis-access"
    Type = "iam-policy"
  })
}

# SQS Access Policy
resource "aws_iam_policy" "sqs_access" {
  name        = "${var.project_name}-${var.environment}-sqs-access"
  description = "Policy for SQS access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = [
          "arn:${local.partition}:sqs:${local.region}:${local.account_id}:${var.project_name}-*"
        ]
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-sqs-access"
    Type = "iam-policy"
  })
}

# Secrets Manager Access Policy
resource "aws_iam_policy" "secrets_access" {
  name        = "${var.project_name}-${var.environment}-secrets-access"
  description = "Policy for Secrets Manager access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [
          "arn:${local.partition}:secretsmanager:${local.region}:${local.account_id}:secret:${var.project_name}/*"
        ]
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-secrets-access"
    Type = "iam-policy"
  })
}

# CloudWatch Logs Policy
resource "aws_iam_policy" "cloudwatch_logs" {
  name        = "${var.project_name}-${var.environment}-cloudwatch-logs"
  description = "Policy for CloudWatch Logs access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = [
          "arn:${local.partition}:logs:${local.region}:${local.account_id}:log-group:/aws/microservices/${var.project_name}*"
        ]
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-cloudwatch-logs"
    Type = "iam-policy"
  })
}

# ===================================================================
# Data Processing Service Role
# ===================================================================
resource "aws_iam_role" "data_processing" {
  name        = "${var.project_name}-${var.environment}-data-processing-role"
  description = "Role for data processing services"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "ec2.amazonaws.com",
            "ecs-tasks.amazonaws.com",
            "lambda.amazonaws.com"
          ]
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-data-processing-role"
    Type = "iam-role"
  })
}

resource "aws_iam_role_policy_attachment" "data_processing_policies" {
  for_each = toset([
    aws_iam_policy.s3_data_access.arn,
    aws_iam_policy.kinesis_access.arn,
    aws_iam_policy.sqs_access.arn,
    aws_iam_policy.secrets_access.arn,
    aws_iam_policy.cloudwatch_logs.arn
  ])

  role       = aws_iam_role.data_processing.name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "data_processing" {
  name = "${var.project_name}-${var.environment}-data-processing-profile"
  role = aws_iam_role.data_processing.name

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-data-processing-profile"
    Type = "iam-instance-profile"
  })
}
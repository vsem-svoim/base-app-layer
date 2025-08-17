# ===================================================================
# S3 Module for Data Storage
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

# ===================================================================
# Local Values
# ===================================================================
locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

# ===================================================================
# S3 Buckets
# ===================================================================
resource "aws_s3_bucket" "main" {
  for_each = var.data_storage_config.s3_buckets

  bucket = "${each.value.name}-${var.environment}-${local.account_id}"

  tags = merge(var.common_tags, {
    Name        = each.value.name
    Environment = var.environment
    Type        = "s3-bucket"
    Purpose     = "data-storage"
  })
}

# ===================================================================
# S3 Bucket Versioning
# ===================================================================
resource "aws_s3_bucket_versioning" "main" {
  for_each = {
    for k, v in var.data_storage_config.s3_buckets : k => v
    if v.versioning
  }

  bucket = aws_s3_bucket.main[each.key].id
  versioning_configuration {
    status = "Enabled"
  }
}

# ===================================================================
# S3 Bucket Server Side Encryption
# ===================================================================
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  for_each = var.data_storage_config.s3_buckets

  bucket = aws_s3_bucket.main[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.s3[each.key].arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# ===================================================================
# S3 Bucket Public Access Block
# ===================================================================
resource "aws_s3_bucket_public_access_block" "main" {
  for_each = var.data_storage_config.s3_buckets

  bucket = aws_s3_bucket.main[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ===================================================================
# S3 Bucket Lifecycle Configuration
# ===================================================================
resource "aws_s3_bucket_lifecycle_configuration" "main" {
  for_each = {
    for k, v in var.data_storage_config.s3_buckets : k => v
    if v.lifecycle_rules
  }

  bucket = aws_s3_bucket.main[each.key].id

  rule {
    id     = "data_lifecycle"
    status = "Enabled"

    # Current version transitions
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = each.value.glacier_transition_days
      storage_class = "GLACIER"
    }

    transition {
      days          = each.value.glacier_transition_days + 90
      storage_class = "DEEP_ARCHIVE"
    }

    # Non-current version transitions
    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = each.value.glacier_transition_days
      storage_class   = "GLACIER"
    }

    # Delete old versions
    noncurrent_version_expiration {
      noncurrent_days = 365
    }

    # Delete incomplete multipart uploads
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.main]
}

# ===================================================================
# KMS Keys for S3 Encryption
# ===================================================================
resource "aws_kms_key" "s3" {
  for_each = var.data_storage_config.s3_buckets

  description             = "KMS key for S3 bucket ${each.value.name}"
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
        Sid    = "EnableS3Service"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "s3.${local.region}.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name    = "${each.value.name}-s3-key"
    Type    = "kms-key"
    Purpose = "s3-encryption"
  })
}

resource "aws_kms_alias" "s3" {
  for_each = var.data_storage_config.s3_buckets

  name          = "alias/${var.project_name}-${each.key}-s3"
  target_key_id = aws_kms_key.s3[each.key].key_id
}

# ===================================================================
# S3 Bucket Notifications (Optional)
# ===================================================================
resource "aws_s3_bucket_notification" "main" {
  for_each = var.data_storage_config.s3_buckets

  bucket = aws_s3_bucket.main[each.key].id

  # SQS notification for object creation
  queue {
    queue_arn = aws_sqs_queue.s3_notifications[each.key].arn
    events    = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_sqs_queue_policy.s3_notifications]
}

# ===================================================================
# SQS Queues for S3 Notifications
# ===================================================================
resource "aws_sqs_queue" "s3_notifications" {
  for_each = var.data_storage_config.s3_buckets

  name                       = "${var.project_name}-${each.key}-s3-notifications"
  message_retention_seconds  = 1209600 # 14 days
  visibility_timeout_seconds = 300

  # Encryption
  kms_master_key_id                 = aws_kms_key.s3[each.key].arn
  kms_data_key_reuse_period_seconds = 300

  tags = merge(var.common_tags, {
    Name    = "${var.project_name}-${each.key}-s3-notifications"
    Type    = "sqs-queue"
    Purpose = "s3-notifications"
  })
}

resource "aws_sqs_queue_policy" "s3_notifications" {
  for_each = var.data_storage_config.s3_buckets

  queue_url = aws_sqs_queue.s3_notifications[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.s3_notifications[each.key].arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_s3_bucket.main[each.key].arn
          }
        }
      }
    ]
  })
}
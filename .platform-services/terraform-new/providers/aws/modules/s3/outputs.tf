# ===================================================================
# S3 Module Outputs
# ===================================================================

output "bucket_ids" {
  description = "Map of S3 bucket IDs"
  value = {
    for k, v in aws_s3_bucket.main : k => v.id
  }
}

output "bucket_arns" {
  description = "Map of S3 bucket ARNs"
  value = {
    for k, v in aws_s3_bucket.main : k => v.arn
  }
}

output "bucket_domain_names" {
  description = "Map of S3 bucket domain names"
  value = {
    for k, v in aws_s3_bucket.main : k => v.bucket_domain_name
  }
}

output "bucket_regional_domain_names" {
  description = "Map of S3 bucket regional domain names"
  value = {
    for k, v in aws_s3_bucket.main : k => v.bucket_regional_domain_name
  }
}

output "kms_key_ids" {
  description = "Map of KMS key IDs for S3 buckets"
  value = {
    for k, v in aws_kms_key.s3 : k => v.key_id
  }
}

output "kms_key_arns" {
  description = "Map of KMS key ARNs for S3 buckets"
  value = {
    for k, v in aws_kms_key.s3 : k => v.arn
  }
}

output "notification_queue_arns" {
  description = "Map of SQS queue ARNs for S3 notifications"
  value = {
    for k, v in aws_sqs_queue.s3_notifications : k => v.arn
  }
}

output "notification_queue_urls" {
  description = "Map of SQS queue URLs for S3 notifications"
  value = {
    for k, v in aws_sqs_queue.s3_notifications : k => v.id
  }
}
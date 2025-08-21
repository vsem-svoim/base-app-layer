# ===================================================================
# IAM Module Outputs
# ===================================================================

output "service_role_arns" {
  description = "Map of service role ARNs"
  value = {
    for k, v in aws_iam_role.service_roles : k => v.arn
  }
}

output "service_role_names" {
  description = "Map of service role names"
  value = {
    for k, v in aws_iam_role.service_roles : k => v.name
  }
}

output "instance_profile_arns" {
  description = "Map of instance profile ARNs"
  value = {
    for k, v in aws_iam_instance_profile.service_roles : k => v.arn
  }
}

output "instance_profile_names" {
  description = "Map of instance profile names"
  value = {
    for k, v in aws_iam_instance_profile.service_roles : k => v.name
  }
}

output "data_processing_role_arn" {
  description = "ARN of the data processing role"
  value       = aws_iam_role.data_processing.arn
}

output "data_processing_role_name" {
  description = "Name of the data processing role"
  value       = aws_iam_role.data_processing.name
}

output "data_processing_instance_profile_arn" {
  description = "ARN of the data processing instance profile"
  value       = aws_iam_instance_profile.data_processing.arn
}

output "data_processing_instance_profile_name" {
  description = "Name of the data processing instance profile"
  value       = aws_iam_instance_profile.data_processing.name
}

output "custom_policy_arns" {
  description = "ARNs of custom policies"
  value = {
    s3_data_access  = aws_iam_policy.s3_data_access.arn
    kinesis_access  = aws_iam_policy.kinesis_access.arn
    sqs_access      = aws_iam_policy.sqs_access.arn
    secrets_access  = aws_iam_policy.secrets_access.arn
    cloudwatch_logs = aws_iam_policy.cloudwatch_logs.arn
  }
}
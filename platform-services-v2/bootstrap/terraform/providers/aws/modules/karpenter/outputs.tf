# ===================================================================
# Karpenter Module Outputs
# ===================================================================

output "karpenter_namespace" {
  description = "Karpenter namespace"
  value       = var.enable_karpenter ? kubernetes_namespace.karpenter[0].metadata[0].name : null
}

output "karpenter_instance_profile_name" {
  description = "Karpenter node instance profile name"
  value       = aws_iam_instance_profile.karpenter_node_instance_profile.name
}

output "karpenter_instance_profile_arn" {
  description = "Karpenter node instance profile ARN"
  value       = aws_iam_instance_profile.karpenter_node_instance_profile.arn
}

output "karpenter_node_role_arn" {
  description = "Karpenter node IAM role ARN"
  value       = aws_iam_role.karpenter_node_instance_role.arn
}

output "karpenter_node_role_name" {
  description = "Karpenter node IAM role name"
  value       = aws_iam_role.karpenter_node_instance_role.name
}

output "karpenter_helm_release_status" {
  description = "Karpenter Helm release status"
  value       = var.enable_karpenter ? helm_release.karpenter[0].status : "disabled"
}

output "karpenter_version" {
  description = "Deployed Karpenter version"
  value       = var.karpenter_version
}

output "nodepool_name" {
  description = "Karpenter NodePool name"
  value       = "base-data-processing"
}

output "nodeclass_name" {
  description = "Karpenter EC2NodeClass name"
  value       = "base-data-processing"
}
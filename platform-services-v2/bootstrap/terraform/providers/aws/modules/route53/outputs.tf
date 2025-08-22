# ===================================================================
# Route 53 Module Outputs
# ===================================================================

output "hosted_zone_id" {
  description = "Route 53 hosted zone ID"
  value       = data.aws_route53_zone.main.zone_id
}

output "hosted_zone_name" {
  description = "Route 53 hosted zone name"
  value       = data.aws_route53_zone.main.name
}

output "name_servers" {
  description = "Route 53 hosted zone name servers"
  value       = data.aws_route53_zone.main.name_servers
}

output "platform_fqdn" {
  description = "Platform subdomain FQDN"
  value       = var.platform_subdomain
}

output "platform_record_name" {
  description = "Platform DNS A record name"
  value       = aws_route53_record.platform_subdomain.name
}

output "health_check_id" {
  description = "Route 53 health check ID"
  value       = var.enable_health_checks ? aws_route53_health_check.platform_health[0].id : null
}
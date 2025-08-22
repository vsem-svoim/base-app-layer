# ===================================================================
# ACM Module Outputs
# ===================================================================

output "certificate_arn" {
  description = "ARN of the SSL certificate"
  value       = var.import_existing_wildcard ? data.aws_acm_certificate.existing_wildcard[0].arn : aws_acm_certificate_validation.platform_ssl.certificate_arn
}

output "certificate_domain" {
  description = "Domain name of the SSL certificate"
  value       = var.platform_domain
}

output "certificate_status" {
  description = "SSL certificate status"
  value       = var.import_existing_wildcard ? data.aws_acm_certificate.existing_wildcard[0].status : "PENDING_VALIDATION"
}

output "domain_validation_options" {
  description = "Domain validation options for DNS records"
  value = var.import_existing_wildcard ? {} : {
    for dvo in aws_acm_certificate.platform_ssl.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      value  = dvo.resource_record_value
    }
  }
  sensitive = false
}
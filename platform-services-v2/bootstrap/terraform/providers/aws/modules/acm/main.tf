# ===================================================================
# ACM SSL Certificate Configuration  
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
# SSL Certificate for Platform Domain
# ===================================================================

resource "aws_acm_certificate" "platform_ssl" {
  domain_name       = var.platform_domain
  validation_method = "DNS"

  subject_alternative_names = var.additional_domains

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-ssl-certificate"
    Type = "SSL Certificate"
    Domain = var.platform_domain
  })
}

# ===================================================================
# Certificate Validation (depends on Route 53 records)
# ===================================================================

resource "aws_acm_certificate_validation" "platform_ssl" {
  certificate_arn         = aws_acm_certificate.platform_ssl.arn
  validation_record_fqdns = [for record in aws_acm_certificate.platform_ssl.domain_validation_options : record.resource_record_name]

  timeouts {
    create = "10m"
  }

  depends_on = [aws_acm_certificate.platform_ssl]
}

# ===================================================================
# Data source for existing certificates (if importing)
# ===================================================================

data "aws_acm_certificate" "existing_wildcard" {
  count  = var.import_existing_wildcard ? 1 : 0
  domain = "*.${var.base_domain}"
  
  most_recent = true
  statuses    = ["ISSUED"]
}
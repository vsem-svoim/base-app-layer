# ===================================================================
# Route 53 DNS Configuration
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
# Route 53 Hosted Zone
# ===================================================================

# Import existing hosted zone (created during domain registration)
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

# ===================================================================
# DNS Records for Platform Services  
# ===================================================================

# Main platform subdomain A record pointing to ALB
resource "aws_route53_record" "platform_subdomain" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.platform_subdomain
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id               = var.alb_zone_id
    evaluate_target_health = true
  }

  depends_on = [data.aws_route53_zone.main]
}

# Certificate validation records (managed by ACM module)
resource "aws_route53_record" "certificate_validation" {
  for_each = var.certificate_validation_records

  zone_id = data.aws_route53_zone.main.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.value]
  ttl     = 300

  depends_on = [data.aws_route53_zone.main]
}

# ===================================================================
# Health Checks (Optional)
# ===================================================================

resource "aws_route53_health_check" "platform_health" {
  count                           = var.enable_health_checks ? 1 : 0
  
  fqdn                           = var.platform_subdomain
  port                           = 443
  type                           = "HTTPS"
  resource_path                  = "/health"
  failure_threshold              = "3"
  request_interval               = "30"
  cloudwatch_alarm_region        = var.region
  cloudwatch_alarm_name          = "${var.project_name}-${var.environment}-platform-health"
  insufficient_data_health_status = "LastKnownStatus"

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-platform-health"
    Type = "HealthCheck"
  })
}
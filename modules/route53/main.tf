# -------------------------------------------------------
# HOSTED ZONE
# Subdomain zone for redline.fourallthedogs.com.
# Same delegation pattern as OpenCourt —
# the parent zone (fourallthedogs.com) lives in
# coffee-terraform. After terraform apply, add an NS
# record in the parent zone pointing to these nameservers.
# -------------------------------------------------------
resource "aws_route53_zone" "main" {
  name = var.subdomain

  tags = {
    Project = var.project
  }
}

# -------------------------------------------------------
# FRONTEND RECORD
# redline.fourallthedogs.com -> CloudFront distribution
# -------------------------------------------------------
resource "aws_route53_record" "frontend" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.subdomain
  type    = "A"

  alias {
    name                   = var.cloudfront_domain
    zone_id                = var.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}

# -------------------------------------------------------
# API RECORD
# api.redline.fourallthedogs.com -> ALB
# Only created after the ALB exists (after Helm deploy).
# Set alb_dns_name variable then run terraform apply again.
# -------------------------------------------------------
resource "aws_route53_record" "api" {
  count = var.alb_dns_name != "" ? 1 : 0

  zone_id = aws_route53_zone.main.zone_id
  name    = "api.${var.subdomain}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_hosted_zone_id
    evaluate_target_health = true
  }
}

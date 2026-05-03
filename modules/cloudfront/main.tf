# -------------------------------------------------------
# S3 BUCKET
# Hosts the React frontend — HTML, CSS, JS.
# Private bucket — CloudFront accesses it via OAC.
# Nobody can hit S3 directly.
# -------------------------------------------------------
resource "aws_s3_bucket" "frontend" {
  bucket = "${var.project}-frontend"

  tags = {
    Project = var.project
  }
}

# Block all public access — CloudFront only via OAC
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html" # SPA routing — all 404s return index.html
  }
}

# -------------------------------------------------------
# ORIGIN ACCESS CONTROL
# Modern replacement for OAI — lets CloudFront access
# the private S3 bucket securely using SigV4 signing.
# -------------------------------------------------------
resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${var.project}-frontend-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# -------------------------------------------------------
# S3 BUCKET POLICY
# Only allows CloudFront (via OAC) to read objects.
# -------------------------------------------------------
resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.frontend.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.frontend.arn
          }
        }
      }
    ]
  })
}

# -------------------------------------------------------
# ACM CERTIFICATE
# Must be in us-east-1 for CloudFront regardless of
# where the rest of the infrastructure lives.
# Uses the us_east_1 provider alias from root main.tf.
# -------------------------------------------------------
resource "aws_acm_certificate" "frontend" {
  provider                  = aws.us_east_1
  domain_name               = var.subdomain
  subject_alternative_names = ["*.${var.subdomain}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Project = var.project
  }
}

resource "aws_route53_record" "frontend_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.frontend.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id         = var.route53_zone_id
  name            = each.value.name
  type            = each.value.type
  ttl             = 3600
  records         = [each.value.record]
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "frontend" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.frontend.arn
  validation_record_fqdns = [for record in aws_route53_record.frontend_cert_validation : record.fqdn]
}

# -------------------------------------------------------
# WAF WEB ACL
# Attached to CloudFront — filters malicious traffic
# at the edge before it reaches S3.
# Must be in us-east-1 for CloudFront.
# -------------------------------------------------------
resource "aws_wafv2_web_acl" "frontend" {
  provider = aws.us_east_1
  name     = "${var.project}-frontend-waf"
  scope    = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # Rate limiting — blocks IPs making excessive requests
  rule {
    name     = "RateLimitPerIP"
    priority = 0

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitPerIP"
    }
  }

  # AWS IP Reputation List — blocks known malicious IPs
  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesAmazonIpReputationList"
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesAmazonIpReputationList"
    }
  }

  # Common Rule Set — SQL injection, XSS, path traversal
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSet"
    }
  }

  visibility_config {
    sampled_requests_enabled   = true
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project}-frontend-waf"
  }

  tags = {
    Project = var.project
  }
}

# -------------------------------------------------------
# CLOUDFRONT DISTRIBUTION
# Serves the React frontend from S3.
# WAF filters traffic at the edge.
# SPA routing handled via custom error responses.
# -------------------------------------------------------
resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100" # US, Canada, Europe — cheapest tier
  http_version        = "http2"
  is_ipv6_enabled     = true
  comment             = "${var.project} frontend"
  aliases             = [var.subdomain]
  web_acl_id          = aws_wafv2_web_acl.frontend.arn

  # S3 origin via OAC
  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  default_cache_behavior {
    target_origin_id       = aws_s3_bucket.frontend.bucket_regional_domain_name
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    allowed_methods = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
    cached_methods  = ["HEAD", "GET"]

    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingDisabled
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac" # CORS-S3Origin
  }

  # SPA routing — any 403/404 returns index.html
  # Lets React Router handle URLs like /listings/123
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.frontend.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Project = var.project
  }

  depends_on = [aws_acm_certificate_validation.frontend]
}

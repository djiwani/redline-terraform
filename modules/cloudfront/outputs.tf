output "cloudfront_domain" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID — used for cache invalidation in GitHub Actions"
  value       = aws_cloudfront_distribution.frontend.id
}

output "cloudfront_hosted_zone_id" {
  description = "CloudFront hosted zone ID — used for Route53 alias record"
  value       = aws_cloudfront_distribution.frontend.hosted_zone_id
}

output "s3_bucket_name" {
  description = "Frontend S3 bucket name — used by GitHub Actions to sync build files"
  value       = aws_s3_bucket.frontend.bucket
}

output "acm_certificate_arn" {
  description = "Wildcard ACM cert ARN — used by both CloudFront and ALB ingress"
  value       = aws_acm_certificate_validation.frontend.certificate_arn
}

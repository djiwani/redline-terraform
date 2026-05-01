variable "project" {
  description = "Project name"
  type        = string
}

variable "subdomain" {
  description = "Subdomain for Redline e.g. redline.fourallthedogs.com"
  type        = string
}

variable "cloudfront_domain" {
  description = "CloudFront distribution domain name — from cloudfront module"
  type        = string
}

variable "cloudfront_hosted_zone_id" {
  description = "CloudFront hosted zone ID — from cloudfront module"
  type        = string
}

variable "alb_dns_name" {
  description = "ALB DNS name — created by AWS Load Balancer Controller after Helm deploy"
  type        = string
}

variable "alb_hosted_zone_id" {
  description = "ALB hosted zone ID — needed for Route53 alias record"
  type        = string
}

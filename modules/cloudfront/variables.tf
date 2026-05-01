variable "project" {
  description = "Project name"
  type        = string
}

variable "subdomain" {
  description = "Frontend subdomain e.g. redline.fourallthedogs.com"
  type        = string
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for DNS validation and records"
  type        = string
}

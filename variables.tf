variable "region" {
  default = "us-east-1"
}

variable "project" {
  default = "redline"
}

variable "domain" {
  default = "fourallthedogs.com"
}

variable "subdomain" {
  default = "redline.fourallthedogs.com"
}

variable "db_name" {
  default = "redline"
}

variable "db_username" {
  default = "redline_admin"
}

variable "container_port" {
  default = 8000 # FastAPI default
}

variable "vpc_cidr" {
  default = "10.5.0.0/16"
}

variable "availability_zones" {
  default = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  default = ["10.5.1.0/24", "10.5.2.0/24"]
}

variable "private_subnet_cidrs" {
  default = ["10.5.10.0/24", "10.5.11.0/24"]
}

variable "notification_email" {
  description = "Email for deal reached / negotiation failed notifications"
  default     = "djiwani05@gmail.com"
}

variable "owner_email" {
  description = "Email for owner operational alerts"
  default     = "djiwani05@gmail.com"
}

variable "alb_hosted_zone_id" {
  description = "ALB hosted zone ID for Route53 alias"
  type        = string
  default     = "Z35SXDOTRQ7X7K" # us-east-1 ALB hosted zone ID — always this value
}

variable "alb_dns_name" {
  description = "ALB DNS name — from AWS Load Balancer Controller"
  type        = string
  default     = "k8s-redlineapi-f589e88a27-1108523237.us-east-1.elb.amazonaws.com"
}
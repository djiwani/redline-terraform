variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.region))
    error_message = "Region must be a valid AWS region format e.g. us-east-1."
  }
}

variable "project" {
  description = "Project name used for resource naming"
  type        = string
  default     = "redline"
  validation {
    condition     = length(var.project) > 0 && length(var.project) <= 20
    error_message = "Project name must be between 1 and 20 characters."
  }
}

variable "domain" {
  description = "Root domain name"
  type        = string
  default     = "fourallthedogs.com"
}

variable "subdomain" {
  description = "Subdomain for this project"
  type        = string
  default     = "redline.fourallthedogs.com"
}

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "redline"
  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.db_name))
    error_message = "Database name must start with a letter and contain only letters, numbers, and underscores."
  }
}

variable "db_username" {
  description = "PostgreSQL master username"
  type        = string
  default     = "redline_admin"
  validation {
    condition     = length(var.db_username) >= 4
    error_message = "Database username must be at least 4 characters."
  }
}

variable "container_port" {
  description = "Port the FastAPI containers listen on"
  type        = number
  default     = 8000
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.5.0.0/16"
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "availability_zones" {
  description = "Availability zones to deploy subnets into"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least two availability zones are required for high availability."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets, one per AZ"
  type        = list(string)
  default     = ["10.5.1.0/24", "10.5.2.0/24"]
  validation {
    condition     = alltrue([for cidr in var.public_subnet_cidrs : can(cidrhost(cidr, 0))])
    error_message = "All public subnet CIDRs must be valid IPv4 CIDR blocks."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets, one per AZ"
  type        = list(string)
  default     = ["10.5.10.0/24", "10.5.11.0/24"]
  validation {
    condition     = alltrue([for cidr in var.private_subnet_cidrs : can(cidrhost(cidr, 0))])
    error_message = "All private subnet CIDRs must be valid IPv4 CIDR blocks."
  }
}

variable "notification_email" {
  description = "Email for deal reached / negotiation failed notifications"
  type        = string
  default     = "djiwani05@gmail.com"
  validation {
    condition     = can(regex("^[^@]+@[^@]+\\.[^@]+$", var.notification_email))
    error_message = "Must be a valid email address."
  }
}

variable "owner_email" {
  description = "Email for owner operational alerts"
  type        = string
  default     = "djiwani05@gmail.com"
  validation {
    condition     = can(regex("^[^@]+@[^@]+\\.[^@]+$", var.owner_email))
    error_message = "Must be a valid email address."
  }
}

variable "alb_hosted_zone_id" {
  description = "ALB hosted zone ID for Route53 alias — always Z35SXDOTRQ7X7K for us-east-1"
  type        = string
  default     = "Z35SXDOTRQ7X7K"
}

variable "alb_dns_name" {
  description = "ALB DNS name — populated after AWS Load Balancer Controller creates the ALB post Helm deploy"
  type        = string
  default     = "k8s-redlineapi-f589e88a27-2067815188.us-east-1.elb.amazonaws.com"
}

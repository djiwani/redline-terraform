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

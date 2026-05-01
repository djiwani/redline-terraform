terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    # Reuses the same state bucket/lock table from OpenCourt
    bucket         = "jiwani-terraform-state"
    key            = "redline/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}

provider "aws" {
  region  = var.region
  profile = "dev"
}

# us-east-1 alias required for ACM + WAF + CloudFront
# Same pattern as OpenCourt cloudfront-api.tf
provider "aws" {
  alias   = "us_east_1"
  region  = "us-east-1"
  profile = "dev"
}

# -------------------------------------------------------
# Networking
# -------------------------------------------------------
module "networking" {
  source = "./modules/networking"

  project              = var.project
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

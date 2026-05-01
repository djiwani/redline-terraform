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
    # Needed to read the EKS cluster OIDC certificate for IRSA
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    # Needed to install the AWS Load Balancer Controller onto the cluster
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
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

# Helm provider needs to know how to talk to the EKS cluster
# It uses the cluster endpoint and certificate from the EKS module
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
      command     = "aws"
    }
  }
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

# -------------------------------------------------------
# EKS
# -------------------------------------------------------
module "eks" {
  source = "./modules/eks"

  project            = var.project
  vpc_id             = module.networking.vpc_id
  public_subnet_ids  = module.networking.public_subnet_ids
  private_subnet_ids = module.networking.private_subnet_ids
  eks_nodes_sg_id    = module.networking.eks_nodes_sg_id
}

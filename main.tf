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
    # Reads the EKS cluster OIDC certificate for IRSA
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    # Installs the AWS Load Balancer Controller onto the cluster
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }

  # Local backend — state file lives on your machine
  # Simple and reliable for a solo portfolio project
  # terraform.tfstate is gitignored so it never gets committed
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region  = var.region
  profile = "dev"
}

# us-east-1 alias required for ACM + WAF + CloudFront
provider "aws" {
  alias   = "us_east_1"
  region  = "us-east-1"
  profile = "dev"
}

# Helm provider authenticates to EKS using the AWS CLI
# Requires: aws CLI configured locally with dev profile
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--profile", "dev"]
      command     = "aws"
    }
  }
}

# -------------------------------------------------------
# NETWORKING
# Everything else depends on this — run first.
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
# Cluster, node group, and OIDC provider for IRSA.
# Takes ~15 minutes to provision.
# -------------------------------------------------------
module "eks" {
  source = "./modules/eks"

  project            = var.project
  vpc_id             = module.networking.vpc_id
  public_subnet_ids  = module.networking.public_subnet_ids
  private_subnet_ids = module.networking.private_subnet_ids
  eks_nodes_sg_id    = module.networking.eks_nodes_sg_id
}

# -------------------------------------------------------
# ECR
# Create repos before pushing any images.
# -------------------------------------------------------
module "ecr" {
  source  = "./modules/ecr"
  project = var.project
}

# -------------------------------------------------------
# RDS
# Takes ~10 minutes to provision.
# -------------------------------------------------------
module "rds" {
  source = "./modules/rds"

  project            = var.project
  db_name            = var.db_name
  db_username        = var.db_username
  private_subnet_ids = module.networking.private_subnet_ids
  rds_sg_id          = module.networking.rds_sg_id
}

# -------------------------------------------------------
# DYNAMODB
# -------------------------------------------------------
module "dynamodb" {
  source  = "./modules/dynamodb"
  project = var.project
}

# -------------------------------------------------------
# SNS
# -------------------------------------------------------
module "sns" {
  source = "./modules/sns"

  project            = var.project
  notification_email = var.notification_email
  owner_email        = var.owner_email
}

# -------------------------------------------------------
# COGNITO
# -------------------------------------------------------
module "cognito" {
  source = "./modules/cognito"

  project   = var.project
  subdomain = var.subdomain
}

# -------------------------------------------------------
# IRSA
# IAM roles for pods — depends on RDS, DynamoDB, SNS
# so those must exist first to get their ARNs.
# -------------------------------------------------------
module "irsa" {
  source = "./modules/irsa"

  project                    = var.project
  region                     = var.region
  account_id                 = "856888988892"
  oidc_provider_arn          = module.eks.oidc_provider_arn
  oidc_issuer_url            = module.eks.cluster_oidc_issuer
  db_secret_arn              = module.rds.db_secret_arn
  dynamodb_table_arn         = module.dynamodb.table_arn
  sns_deal_reached_arn       = module.sns.deal_reached_arn
  sns_negotiation_failed_arn = module.sns.negotiation_failed_arn
}

# -------------------------------------------------------
# AWS LOAD BALANCER CONTROLLER
# Installed via Helm onto the EKS cluster.
# Watches for Kubernetes Ingress resources and creates
# real AWS ALBs automatically.
# Depends on: EKS cluster + IRSA role
# -------------------------------------------------------
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.7.2"

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  # Annotate the service account with the IRSA role ARN
  # This is what links the pod to the IAM role
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.irsa.load_balancer_controller_role_arn
  }

  set {
    name  = "region"
    value = var.region
  }

  set {
    name  = "vpcId"
    value = module.networking.vpc_id
  }

  depends_on = [
    module.eks,
    module.irsa
  ]
}

# -------------------------------------------------------
# ROUTE53
# Zone created first so zone ID is available for
# CloudFront ACM cert DNS validation.
# ALB record filled in after Helm deploy creates the ALB.
# -------------------------------------------------------
module "route53" {
  source = "./modules/route53"

  project                   = var.project
  subdomain                 = var.subdomain
  cloudfront_domain         = module.cloudfront.cloudfront_domain
  cloudfront_hosted_zone_id = module.cloudfront.cloudfront_hosted_zone_id
  alb_dns_name              = var.alb_dns_name
  alb_hosted_zone_id        = var.alb_hosted_zone_id
}

# -------------------------------------------------------
# CLOUDFRONT + S3 (frontend)
# -------------------------------------------------------
module "cloudfront" {
  source = "./modules/cloudfront"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  project         = var.project
  subdomain       = var.subdomain
  route53_zone_id = module.route53.zone_id
}

# -------------------------------------------------------
# CLOUDWATCH
# -------------------------------------------------------
module "cloudwatch" {
  source = "./modules/cloudwatch"

  project                = var.project
  region                 = var.region
  cluster_name           = module.eks.cluster_name
  db_instance_identifier = "${var.project}-postgres"
  dynamodb_table_name    = module.dynamodb.table_name
  owner_alerts_arn       = module.sns.owner_alerts_arn
}

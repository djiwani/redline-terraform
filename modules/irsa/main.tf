# -------------------------------------------------------
# HOW IRSA WORKS
# Each IAM role has a trust policy that says:
# "Only allow the service account named X in namespace Y
# inside cluster Z to assume this role."
# That's the OIDC condition at the bottom of each trust policy.
# -------------------------------------------------------

locals {
  # Strip the https:// from the OIDC issuer URL
  # IAM trust policies need it without the protocol prefix
  oidc_issuer = replace(var.oidc_issuer_url, "https://", "")
}

# -------------------------------------------------------
# AWS LOAD BALANCER CONTROLLER
# Needs broad ALB/EC2 permissions to create and manage
# load balancers on behalf of your Kubernetes Ingress resources.
# Runs in kube-system namespace, not redline.
# -------------------------------------------------------
resource "aws_iam_role" "load_balancer_controller" {
  name = "${var.project}-load-balancer-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_issuer}:aud" = "sts.amazonaws.com"
            "${local.oidc_issuer}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  })

  tags = {
    Project = var.project
  }
}

# AWS provides the official policy for the Load Balancer Controller
# It's a long list of EC2/ALB/IAM permissions — no need to write it manually
resource "aws_iam_policy" "load_balancer_controller" {
  name        = "${var.project}-load-balancer-controller-policy"
  description = "Policy for AWS Load Balancer Controller"

  # This is the official AWS-provided policy for the Load Balancer Controller
  policy = file("${path.module}/policies/load-balancer-controller.json")

  tags = {
    Project = var.project
  }
}

resource "aws_iam_role_policy_attachment" "load_balancer_controller" {
  role       = aws_iam_role.load_balancer_controller.name
  policy_arn = aws_iam_policy.load_balancer_controller.arn
}

# -------------------------------------------------------
# NEGOTIATION SERVICE
# Needs: Bedrock (invoke model), DynamoDB (read/write),
# SNS (publish), Secrets Manager (get secret)
# -------------------------------------------------------
resource "aws_iam_role" "negotiation_service" {
  name = "${var.project}-negotiation-service"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_issuer}:aud" = "sts.amazonaws.com"
            "${local.oidc_issuer}:sub" = "system:serviceaccount:${var.namespace}:negotiation-service"
          }
        }
      }
    ]
  })

  tags = {
    Project = var.project
  }
}

resource "aws_iam_role_policy" "negotiation_service" {
  name = "${var.project}-negotiation-service-policy"
  role = aws_iam_role.negotiation_service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Bedrock — invoke Claude Haiku only, not all models
      {
        Effect = "Allow"
        Action = ["bedrock:InvokeModel"]
        Resource = "arn:aws:bedrock:${var.region}::foundation-model/anthropic.claude-haiku-4-5"
      },
      # DynamoDB — negotiation session table only
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:DeleteItem"
        ]
        Resource = [
          var.dynamodb_table_arn,
          "${var.dynamodb_table_arn}/index/*"
        ]
      },
      # SNS — publish deal notifications only
      {
        Effect   = "Allow"
        Action   = ["sns:Publish"]
        Resource = [var.sns_deal_reached_arn, var.sns_negotiation_failed_arn]
      },
      # Secrets Manager — fetch DB credentials
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = var.db_secret_arn
      }
    ]
  })
}

# -------------------------------------------------------
# LISTINGS SERVICE
# Only needs Secrets Manager to fetch RDS credentials.
# No AWS service calls beyond that.
# -------------------------------------------------------
resource "aws_iam_role" "listings_service" {
  name = "${var.project}-listings-service"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_issuer}:aud" = "sts.amazonaws.com"
            "${local.oidc_issuer}:sub" = "system:serviceaccount:${var.namespace}:listings-service"
          }
        }
      }
    ]
  })

  tags = {
    Project = var.project
  }
}

resource "aws_iam_role_policy" "listings_service" {
  name = "${var.project}-listings-service-policy"
  role = aws_iam_role.listings_service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = var.db_secret_arn
      }
    ]
  })
}

# -------------------------------------------------------
# USERS SERVICE
# Needs Secrets Manager for RDS credentials.
# Cognito calls (JWT verification) happen via the
# Cognito public JWKS endpoint — no IAM needed for that.
# -------------------------------------------------------
resource "aws_iam_role" "users_service" {
  name = "${var.project}-users-service"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_issuer}:aud" = "sts.amazonaws.com"
            "${local.oidc_issuer}:sub" = "system:serviceaccount:${var.namespace}:users-service"
          }
        }
      }
    ]
  })

  tags = {
    Project = var.project
  }
}

resource "aws_iam_role_policy" "users_service" {
  name = "${var.project}-users-service-policy"
  role = aws_iam_role.users_service.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = var.db_secret_arn
      }
    ]
  })
}

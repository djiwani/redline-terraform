# -------------------------------------------------------
# IAM ROLE — CLUSTER CONTROL PLANE
# The EKS control plane needs permission to make AWS API
# calls on your behalf — managing EC2s, load balancers,
# security groups etc. This role grants that.
# -------------------------------------------------------
resource "aws_iam_role" "cluster" {
  name = "${var.project}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Project = var.project
  }
}

# AWS managed policy — gives the control plane everything it needs
resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# -------------------------------------------------------
# EKS CLUSTER
# The control plane itself — managed by AWS.
# Lives across multiple AZs automatically.
# -------------------------------------------------------
resource "aws_eks_cluster" "main" {
  name     = "${var.project}-cluster"
  version  = var.kubernetes_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = concat(var.public_subnet_ids, var.private_subnet_ids)
    security_group_ids      = [var.eks_nodes_sg_id]
    endpoint_private_access = true  # Nodes talk to control plane privately
    endpoint_public_access  = true  # You talk to cluster from your laptop
  }

  # Useful logs for debugging — stored in CloudWatch
  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  depends_on = [aws_iam_role_policy_attachment.cluster_policy]

  tags = {
    Project = var.project
  }
}

# -------------------------------------------------------
# IAM ROLE — NODE GROUP
# The EC2 nodes need their own IAM role so they can:
# - Pull images from ECR
# - Register themselves with the cluster
# - Ship logs to CloudWatch
# -------------------------------------------------------
resource "aws_iam_role" "nodes" {
  name = "${var.project}-eks-nodes-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Project = var.project
  }
}

# Three AWS managed policies nodes need — don't need to write these yourself
resource "aws_iam_role_policy_attachment" "nodes_worker_policy" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "nodes_ecr_policy" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "nodes_cni_policy" {
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# -------------------------------------------------------
# NODE GROUP
# The actual EC2 instances your pods run on.
# 2x t3.medium — plenty for a portfolio project.
# Lives in private subnets — nodes never exposed to internet.
# -------------------------------------------------------
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project}-nodes"
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = [var.node_instance_type]

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  # Ignore desired_size changes after initial deploy
  # so manual scaling doesn't get overridden by terraform apply
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  depends_on = [
    aws_iam_role_policy_attachment.nodes_worker_policy,
    aws_iam_role_policy_attachment.nodes_ecr_policy,
    aws_iam_role_policy_attachment.nodes_cni_policy,
  ]

  tags = {
    Project = var.project
  }
}

# -------------------------------------------------------
# OIDC PROVIDER
# This is what makes IRSA work.
# It lets AWS IAM trust the EKS cluster's identity system
# so pods can assume IAM roles.
# Without this, IRSA doesn't work at all.
# -------------------------------------------------------
data "tls_certificate" "cluster" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "cluster" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = {
    Project = var.project
  }
}

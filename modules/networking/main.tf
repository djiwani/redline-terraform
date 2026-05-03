# -------------------------------------------------------
# VPC
# -------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name    = "${var.project}-vpc"
    Project = var.project
  }
}

# -------------------------------------------------------
# Internet Gateway
# -------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project}-igw"
    Project = var.project
  }
}

# -------------------------------------------------------
# Public Subnets (ALB lives here)
# -------------------------------------------------------
resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  # Required for AWS Load Balancer Controller to discover public subnets
  tags = {
    Name                                           = "${var.project}-public-${var.availability_zones[count.index]}"
    Project                                        = var.project
    Tier                                           = "public"
    "kubernetes.io/role/elb"                       = "1"
    "kubernetes.io/cluster/${var.project}-cluster" = "shared"
  }
}

# -------------------------------------------------------
# Private Subnets (EKS nodes + RDS live here)
# -------------------------------------------------------
resource "aws_subnet" "private" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  # Required for AWS Load Balancer Controller to discover private subnets
  tags = {
    Name                                           = "${var.project}-private-${var.availability_zones[count.index]}"
    Project                                        = var.project
    Tier                                           = "private"
    "kubernetes.io/role/internal-elb"              = "1"
    "kubernetes.io/cluster/${var.project}-cluster" = "shared"
  }
}

# -------------------------------------------------------
# NAT Gateway (single, in first public subnet)
# Chosen over VPC endpoints for simplicity at dev scale.
# OpenCourt used VPC endpoints for security posture — Redline
# uses NAT Gateway as a deliberate cost/simplicity tradeoff.
# -------------------------------------------------------
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name    = "${var.project}-nat-eip"
    Project = var.project
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name    = "${var.project}-nat"
    Project = var.project
  }

  depends_on = [aws_internet_gateway.main]
}

# -------------------------------------------------------
# Route Tables
# -------------------------------------------------------

# Public — routes all traffic through IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name    = "${var.project}-public-rt"
    Project = var.project
  }
}

# Private — routes all traffic through NAT Gateway
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name    = "${var.project}-private-rt"
    Project = var.project
  }
}

# -------------------------------------------------------
# Route Table Associations
# -------------------------------------------------------
resource "aws_route_table_association" "public" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = length(var.availability_zones)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# -------------------------------------------------------
# Security Groups
# -------------------------------------------------------

# ALB — accepts HTTPS/HTTP from internet, sends to EKS nodes
resource "aws_security_group" "alb" {
  name        = "${var.project}-alb-sg"
  description = "ALB security group - accepts HTTPS from internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from internet (redirect to HTTPS)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project}-alb-sg"
    Project = var.project
  }
}

# EKS Nodes — accepts traffic from ALB, allows node-to-node for pod communication
resource "aws_security_group" "eks_nodes" {
  name        = "${var.project}-eks-nodes-sg"
  description = "EKS node security group - accepts traffic from ALB, allows node-to-node"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Traffic from ALB"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Nodes need to talk to each other for pod-to-pod communication
  ingress {
    description = "Node to node communication"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project}-eks-nodes-sg"
    Project = var.project
  }
}

# RDS — accepts traffic from EKS nodes only
resource "aws_security_group" "rds" {
  name        = "${var.project}-rds-sg"
  description = "RDS security group - accepts traffic from EKS nodes only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from EKS nodes custom SG"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  ingress {
    description = "PostgreSQL from EKS cluster managed SG"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = ["sg-0d5707830ab9c2820"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project}-rds-sg"
    Project = var.project
  }
}

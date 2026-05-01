# -------------------------------------------------------
# SECRETS MANAGER
# Stores RDS credentials — pods fetch these at startup
# via IRSA rather than hardcoding in environment variables.
# Same pattern as OpenCourt's aurora.tf.
# -------------------------------------------------------
resource "random_password" "db_master" {
  length  = 32
  special = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.project}/db-credentials"
  description             = "RDS PostgreSQL master credentials for ${var.project}"
  recovery_window_in_days = 0 # Allows immediate deletion during dev

  tags = {
    Project = var.project
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id

  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_master.result
    host     = aws_db_instance.main.address
    port     = 5432
    dbname   = var.db_name
  })

  # Wait for RDS to exist so the endpoint is known
  depends_on = [aws_db_instance.main]
}

# -------------------------------------------------------
# DB SUBNET GROUP
# Tells RDS which subnets it can deploy into.
# Always private subnets — RDS never exposed to internet.
# -------------------------------------------------------
resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name    = "${var.project}-db-subnet-group"
    Project = var.project
  }
}

# -------------------------------------------------------
# RDS POSTGRESQL
# Standard PostgreSQL on db.t3.micro — cheapest option.
# Aurora Serverless would scale to zero but costs more
# at low usage. t3.micro is ~$13/month if left running,
# which we won't be doing.
# -------------------------------------------------------
resource "aws_db_instance" "main" {
  identifier = "${var.project}-postgres"

  engine         = "postgres"
  engine_version = "16.3"
  instance_class = var.db_instance_class

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db_master.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_sg_id]

  # Storage
  allocated_storage     = 20   # GB — minimum
  max_allocated_storage = 100  # Autoscaling ceiling
  storage_type          = "gp2"
  storage_encrypted     = true

  # Dev settings
  skip_final_snapshot     = true  # Don't create snapshot on destroy
  deletion_protection     = false # Allow terraform destroy
  backup_retention_period = 1     # 1 day backup retention
  publicly_accessible     = false # Private subnets only

  # Performance Insights — free tier, useful for debugging slow queries
  performance_insights_enabled = true

  tags = {
    Project = var.project
  }
}

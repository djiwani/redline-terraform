output "db_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.address
}

output "db_secret_arn" {
  description = "Secrets Manager ARN for DB credentials — used by IRSA module"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "db_secret_name" {
  description = "Secrets Manager secret name"
  value       = aws_secretsmanager_secret.db_credentials.name
}

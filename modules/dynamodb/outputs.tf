output "table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.negotiation_sessions.name
}

output "table_arn" {
  description = "DynamoDB table ARN — used by IRSA module to scope permissions"
  value       = aws_dynamodb_table.negotiation_sessions.arn
}

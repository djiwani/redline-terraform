output "user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.main.id
}

output "user_pool_client_id" {
  description = "Cognito User Pool Client ID — used by the frontend"
  value       = aws_cognito_user_pool_client.main.id
}

output "user_pool_endpoint" {
  description = "Cognito User Pool endpoint — used by users-service for JWT verification"
  value       = aws_cognito_user_pool.main.endpoint
}

output "hosted_ui_url" {
  description = "Cognito hosted UI URL — where users log in"
  value       = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${var.project == "redline" ? "us-east-1" : "us-east-1"}.amazoncognito.com"
}

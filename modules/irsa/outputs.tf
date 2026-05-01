output "load_balancer_controller_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller"
  value       = aws_iam_role.load_balancer_controller.arn
}

output "negotiation_service_role_arn" {
  description = "IAM role ARN for negotiation-service pods"
  value       = aws_iam_role.negotiation_service.arn
}

output "listings_service_role_arn" {
  description = "IAM role ARN for listings-service pods"
  value       = aws_iam_role.listings_service.arn
}

output "users_service_role_arn" {
  description = "IAM role ARN for users-service pods"
  value       = aws_iam_role.users_service.arn
}

output "dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "listings_service_log_group" {
  description = "CloudWatch log group for listings-service"
  value       = aws_cloudwatch_log_group.listings_service.name
}

output "users_service_log_group" {
  description = "CloudWatch log group for users-service"
  value       = aws_cloudwatch_log_group.users_service.name
}

output "negotiation_service_log_group" {
  description = "CloudWatch log group for negotiation-service"
  value       = aws_cloudwatch_log_group.negotiation_service.name
}

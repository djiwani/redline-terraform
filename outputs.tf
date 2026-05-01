# -------------------------------------------------------
# OUTPUTS
# Run: terraform output
# after apply to get these values for use in
# Helm values, GitHub Actions, and coffee-terraform.
# -------------------------------------------------------

output "nameservers" {
  description = "Add these as NS records in coffee-terraform to delegate redline.fourallthedogs.com"
  value       = module.route53.nameservers
}

output "eks_cluster_name" {
  description = "EKS cluster name — used in kubectl and GitHub Actions"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "ecr_repository_urls" {
  description = "ECR repository URLs — used in Helm values and GitHub Actions"
  value       = module.ecr.repository_urls
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID — used by frontend and users-service"
  value       = module.cognito.user_pool_id
}

output "cognito_user_pool_client_id" {
  description = "Cognito User Pool Client ID — used by frontend"
  value       = module.cognito.user_pool_client_id
}

output "cognito_hosted_ui_url" {
  description = "Cognito hosted UI URL — where users log in"
  value       = module.cognito.hosted_ui_url
}

output "rds_endpoint" {
  description = "RDS endpoint — used by services for DB connection"
  value       = module.rds.db_endpoint
}

output "dynamodb_table_name" {
  description = "DynamoDB negotiation sessions table name"
  value       = module.dynamodb.table_name
}

output "sns_deal_reached_arn" {
  description = "SNS deal reached topic ARN"
  value       = module.sns.deal_reached_arn
}

output "sns_negotiation_failed_arn" {
  description = "SNS negotiation failed topic ARN"
  value       = module.sns.negotiation_failed_arn
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID — used by GitHub Actions for cache invalidation"
  value       = module.cloudfront.cloudfront_distribution_id
}

output "s3_bucket_name" {
  description = "Frontend S3 bucket name — used by GitHub Actions to sync build files"
  value       = module.cloudfront.s3_bucket_name
}

output "dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = module.cloudwatch.dashboard_url
}

output "negotiation_service_role_arn" {
  description = "IRSA role ARN for negotiation-service — used in Helm values"
  value       = module.irsa.negotiation_service_role_arn
}

output "listings_service_role_arn" {
  description = "IRSA role ARN for listings-service — used in Helm values"
  value       = module.irsa.listings_service_role_arn
}

output "users_service_role_arn" {
  description = "IRSA role ARN for users-service — used in Helm values"
  value       = module.irsa.users_service_role_arn
}

variable "project" {
  description = "Project name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name — used for Container Insights log group"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix — used for CloudWatch alarm dimensions"
  type        = string
  default     = ""
}

variable "db_instance_identifier" {
  description = "RDS instance identifier — used for CloudWatch alarm dimensions"
  type        = string
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name — used for dashboard metrics"
  type        = string
}

variable "owner_alerts_arn" {
  description = "SNS topic ARN for owner alerts"
  type        = string
}

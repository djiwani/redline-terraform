variable "project" {
  description = "Project name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace where services run"
  type        = string
  default     = "redline"
}

variable "oidc_provider_arn" {
  description = "OIDC provider ARN from EKS module"
  type        = string
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL from EKS module"
  type        = string
}

variable "db_secret_arn" {
  description = "Secrets Manager ARN for RDS credentials"
  type        = string
}

variable "dynamodb_table_arn" {
  description = "DynamoDB negotiation sessions table ARN"
  type        = string
}

variable "sns_deal_reached_arn" {
  description = "SNS topic ARN for deal reached notifications"
  type        = string
}

variable "sns_negotiation_failed_arn" {
  description = "SNS topic ARN for negotiation failed notifications"
  type        = string
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
}
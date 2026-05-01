output "deal_reached_arn" {
  description = "SNS topic ARN for deal reached — used by IRSA and negotiation-service"
  value       = aws_sns_topic.deal_reached.arn
}

output "negotiation_failed_arn" {
  description = "SNS topic ARN for negotiation failed — used by IRSA and negotiation-service"
  value       = aws_sns_topic.negotiation_failed.arn
}

output "owner_alerts_arn" {
  description = "SNS topic ARN for owner alerts — used by CloudWatch alarms"
  value       = aws_sns_topic.owner_alerts.arn
}

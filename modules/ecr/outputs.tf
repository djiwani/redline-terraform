output "repository_urls" {
  description = "ECR repository URLs keyed by service name — used in Helm values and GitHub Actions"
  value = {
    for service, repo in aws_ecr_repository.services :
    service => repo.repository_url
  }
}

output "registry_id" {
  description = "ECR registry ID — used by GitHub Actions to authenticate"
  value       = values(aws_ecr_repository.services)[0].registry_id
}

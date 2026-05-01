output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint — used by kubectl and helm"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_ca_certificate" {
  description = "Cluster certificate authority data — used by kubectl"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_oidc_issuer" {
  description = "OIDC issuer URL — used by IRSA role trust policies"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN — used by IRSA role trust policies"
  value       = aws_iam_openid_connect_provider.cluster.arn
}

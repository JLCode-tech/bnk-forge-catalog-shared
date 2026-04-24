output "role_arn" {
  value       = aws_iam_role.bedrock.arn
  description = "IAM role ARN. Wire into `bedrock_role_arn` on app/bedrock-smartllm-backend."
}

output "role_name" {
  value       = aws_iam_role.bedrock.name
  description = "Name of the created IAM role."
}

output "oidc_provider_arn" {
  value       = data.aws_iam_openid_connect_provider.eks.arn
  description = "ARN of the EKS OIDC provider the role trusts."
}

output "sa_namespace" {
  value       = var.sa_namespace
  description = "Kubernetes namespace the role is bound to."
}

output "sa_name" {
  value       = var.sa_name
  description = "Kubernetes ServiceAccount name the role is bound to."
}

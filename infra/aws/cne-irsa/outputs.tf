# infra/aws/cne-irsa/outputs.tf

output "role_arn" {
  description = "ARN of the IAM role bound to the CNE controller's ServiceAccount via IRSA"
  value       = aws_iam_role.cne_controller.arn
}

output "role_name" {
  description = "Name of the IAM role"
  value       = aws_iam_role.cne_controller.name
}

output "policy_arn" {
  description = "ARN of the allow-ec2-vip IAM policy"
  value       = aws_iam_policy.allow_ec2_vip.arn
}

output "policy_name" {
  description = "Name of the allow-ec2-vip IAM policy"
  value       = aws_iam_policy.allow_ec2_vip.name
}

output "annotated_serviceaccount" {
  description = "Fully-qualified ServiceAccount that was annotated (namespace/name)"
  value       = "${var.cne_controller_namespace}/${var.cne_controller_sa_name}"
}

output "ready" {
  description = "Flag set after the SA annotation + controller restart completes; downstream modules can gate on this"
  value       = true

  depends_on = [
    null_resource.annotate_and_restart,
  ]
}

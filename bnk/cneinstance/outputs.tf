# bnk/cneinstance/outputs.tf

output "instance_name" {
  description = "Name of the CNEInstance"
  value       = var.instance_name
}

output "instance_namespace" {
  description = "Namespace of the CNEInstance"
  value       = var.instance_namespace
}

output "instance_ready" {
  description = "Gate output — true when CNEInstance is applied and verified"
  value       = true

  depends_on = [null_resource.verify_pods]
}

output "manifest_version" {
  description = "BNK manifest version"
  value       = var.manifest_version
}

output "deployment_size" {
  description = "Deployment size"
  value       = var.deployment_size
}

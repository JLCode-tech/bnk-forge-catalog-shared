# infrastructure-modules/bnk/cneinstance/outputs.tf

output "instance_name" {
  description = "Name of the CNEInstance resource"
  value       = var.instance_name
}

output "instance_namespace" {
  description = "Namespace where CNE instance is deployed"
  value       = var.instance_namespace
}

output "instance_ready" {
  description = "Flag indicating CNE instance is ready"
  value       = true
  depends_on  = [null_resource.verify_instance]
}

output "instance_type" {
  description = "Configured instance type"
  value       = var.instance_config.instance_type
}

output "replicas" {
  description = "Number of replicas configured"
  value       = var.instance_config.replicas
}

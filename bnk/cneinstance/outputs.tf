# infrastructure-modules/bnk/cneinstance/outputs.tf
# CNEInstance Module Outputs - BNK GA 2.2

output "instance_name" {
  description = "Name of the CNEInstance resource"
  value       = var.instance_name
}

output "instance_namespace" {
  description = "Namespace where CNEInstance is deployed"
  value       = var.instance_namespace
}

output "instance_ready" {
  description = "Flag indicating CNEInstance deployment has been initiated"
  value       = true
  depends_on  = [null_resource.verify_instance]
}

output "manifest_version" {
  description = "BNK manifest version deployed"
  value       = var.manifest_version
}

output "deployment_size" {
  description = "Deployment size configured"
  value       = var.deployment_size
}

output "product_type" {
  description = "Product type (BNK or CNF)"
  value       = var.product_type
}

output "gateway_api_enabled" {
  description = "Whether Gateway API is enabled"
  value       = var.gateway_api_enabled
}

output "network_attachments" {
  description = "Network attachment definitions used"
  value       = [var.external_nad_name, var.internal_nad_name]
}

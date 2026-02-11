# bnk-forge-modules/app/demo-gateway/outputs.tf

output "gateway_name" {
  description = "Name of the BNK Gateway"
  value       = kubernetes_manifest.gateway.manifest.metadata.name
}

output "gateway_namespace" {
  description = "Namespace of the BNK Gateway"
  value       = kubernetes_manifest.gateway.manifest.metadata.namespace
}

output "gateway_ready" {
  description = "Flag indicating Gateway is ready for routes and policies"
  value       = true
  depends_on  = [null_resource.verify_gateway]
}

output "listeners" {
  description = "List of configured listener names"
  value       = [for l in local.all_listeners : l.name]
}

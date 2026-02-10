# bnk-forge-modules/bnk/bnk-gatewayclass/outputs.tf

output "gatewayclass_name" {
  description = "Name of the GatewayClass"
  value       = kubernetes_manifest.bnk_gatewayclass.manifest.metadata.name
}

output "gatewayclass_controller" {
  description = "Controller name for the GatewayClass"
  value       = local.controller_name
}

output "gatewayclass_ready" {
  description = "Flag indicating GatewayClass is deployed and accepted"
  value       = true
  depends_on  = [null_resource.verify_gatewayclass]
}

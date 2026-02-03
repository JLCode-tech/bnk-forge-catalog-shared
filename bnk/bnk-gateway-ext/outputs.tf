# bnk-forge-modules/bnk/bnk-gateway-ext/outputs.tf
# F5BnkGateway Module Outputs

output "gateway_ext_name" {
  description = "Name of the created F5BnkGateway"
  value       = var.gateway_ext_name
}

output "gateway_ext_namespace" {
  description = "Namespace of the F5BnkGateway"
  value       = var.namespace
}

output "ipv4_cidr_range" {
  description = "Configured IPv4 CIDR range"
  value       = var.ipv4_cidr_range
}

output "ipv6_cidr_range" {
  description = "Configured IPv6 CIDR range"
  value       = var.ipv6_cidr_range
}

output "gateway_ext_ready" {
  description = "Flag indicating F5BnkGateway was applied"
  value       = length(kubernetes_manifest.f5_bnk_gateway) > 0
}

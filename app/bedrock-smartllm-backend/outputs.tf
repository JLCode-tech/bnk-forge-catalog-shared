output "gateway_name" {
  value       = var.gateway_name
  description = "Name of the BNK Gateway this module created. Client module consumes this to target its traffic."
}

output "gateway_namespace" {
  value       = var.namespace
  description = "Namespace of the BNK Gateway."
}

output "gateway_vip" {
  value       = var.gateway_vip
  description = "VIP the client should POST to."
}

output "httproute_name" {
  value       = var.httproute_name
  description = "Name of the HTTPRoute whose backendRefs the analyzer weights. Dashboard/UI reads weights from here."
}

output "analyzer_name" {
  value       = var.analyzer_name
  description = "Name of the F5BigAnalyzer CR."
}

output "model_service_names" {
  value       = [for k, _ in var.models : k]
  description = "The three Kubernetes Service names that back the HTTPRoute."
}

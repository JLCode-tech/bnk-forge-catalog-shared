# infrastructure-modules/bnk/f5ipamprovider/outputs.tf

output "provider_name" {
  description = "Name of the F5IPAMProvider resource"
  value       = kubernetes_manifest.f5ipamprovider.manifest.metadata.name
}

output "provider_namespace" {
  description = "Namespace where IPAM provider is deployed"
  value       = kubernetes_manifest.f5ipamprovider.manifest.metadata.namespace
}

output "provider_ready" {
  description = "Flag indicating IPAM provider is ready"
  value       = true
  depends_on  = [null_resource.verify_provider]
}

output "provider_type" {
  description = "Configured provider type"
  value       = var.provider_type
}

output "ip_range_count" {
  description = "Number of IP ranges configured"
  value       = length(var.ip_ranges)
}

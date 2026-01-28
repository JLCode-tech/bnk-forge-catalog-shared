# infrastructure-modules/bnk/f5spksnatpool/outputs.tf

output "pool_name" {
  description = "Name of the F5SPKSnatpool resource"
  value       = kubernetes_manifest.f5spksnatpool.manifest.metadata.name
}

output "pool_namespace" {
  description = "Namespace where SNAT pool is deployed"
  value       = kubernetes_manifest.f5spksnatpool.manifest.metadata.namespace
}

output "pool_ready" {
  description = "Flag indicating SNAT pool is ready"
  value       = true
  depends_on  = [null_resource.verify_pool]
}

output "ip_range_count" {
  description = "Number of IP ranges configured"
  value       = length(var.ip_ranges)
}

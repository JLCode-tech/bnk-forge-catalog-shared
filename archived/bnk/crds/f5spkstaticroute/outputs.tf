# infrastructure-modules/bnk/f5spkstaticroute/outputs.tf

output "route_name" {
  description = "Name of the F5SPKStaticRoute resource"
  value       = kubernetes_manifest.f5spkstaticroute.manifest.metadata.name
}

output "route_namespace" {
  description = "Namespace where static route is deployed"
  value       = kubernetes_manifest.f5spkstaticroute.manifest.metadata.namespace
}

output "route_ready" {
  description = "Flag indicating static route is ready"
  value       = true
  depends_on  = [null_resource.verify_route]
}

output "destination" {
  description = "Configured destination network"
  value       = var.destination
}

output "gateway" {
  description = "Configured gateway IP"
  value       = var.gateway
}

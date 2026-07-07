output "observability_namespace" {
  description = "Name of the observability namespace created by this module. Wired into downstream loki, collector, and readiness modules."
  value       = var.observability_namespace
}

output "namespace_ready" {
  description = "Gate output — true once the namespace exists and is Active. Downstream live-observability-loki depends on this."
  value       = true

  depends_on = [
    null_resource.namespace,
  ]
}

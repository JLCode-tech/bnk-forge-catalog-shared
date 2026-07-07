output "loki_endpoint" {
  description = "In-cluster Loki push URL. Format: http://<service>.<namespace>.svc.cluster.local:<port>/loki/api/v1/push. Provided for producer documentation; Fluent Bit uses host/port/uri separately."
  value       = local.loki_endpoint
}

output "loki_service_name" {
  description = "Resolved Loki Kubernetes Service name. Consumed by live-observability-collector (as host component) and live-observability-readiness."
  value       = var.loki_service_name
}

output "loki_port" {
  description = "Resolved Loki HTTP port. Consumed by live-observability-collector and live-observability-readiness."
  value       = var.loki_port
}

output "loki_namespace" {
  description = "Namespace where Loki is deployed. Consumed by live-observability-collector to construct the in-cluster DNS hostname."
  value       = var.observability_namespace
}

output "loki_ready" {
  description = "Gate output — true once Loki manifests have been applied and the Deployment has rolled out. Downstream collector module depends on this."
  value       = true

  depends_on = [
    null_resource.loki_install,
  ]
}

# bnk-forge-modules/app/demo-namespace/outputs.tf

output "app_namespace" {
  description = "Name of the demo applications namespace"
  value       = kubernetes_namespace_v1.app_namespace.metadata[0].name
}

output "gateway_namespace" {
  description = "Name of the gateway namespace"
  value       = kubernetes_namespace_v1.gateway_namespace.metadata[0].name
}

output "observability_namespace" {
  description = "Name of the observability namespace"
  value       = kubernetes_namespace_v1.observability_namespace.metadata[0].name
}

output "namespaces_ready" {
  description = "Flag indicating all namespaces and reference grants are ready"
  value       = true
  depends_on = [
    kubernetes_namespace_v1.app_namespace,
    kubernetes_namespace_v1.gateway_namespace,
    kubernetes_namespace_v1.observability_namespace,
    kubernetes_manifest.reference_grant_apps,
    kubernetes_manifest.reference_grant_observability,
  ]
}

output "cluster_name" {
  description = "The cluster name provided as input. Passed through for downstream documentation and Forge project labelling."
  value       = var.cluster_name
}

output "cluster_api_server" {
  description = "Kubernetes API server URL extracted from the kubeconfig. Useful for diagnostics and Forge cluster registration."
  value       = local.cluster_api_server
}

output "adopt_ready" {
  description = "Gate output — true once kubectl can reach the cluster API server. Downstream namespace/loki/collector/readiness modules depend on this."
  value       = true

  depends_on = [
    null_resource.verify_connectivity,
  ]
}

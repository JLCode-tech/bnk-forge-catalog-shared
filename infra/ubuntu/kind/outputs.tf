output "kubeconfig_path" {
  description = "Path to the kind cluster kubeconfig file"
  value       = local.kubeconfig_path
}

output "cluster_name" {
  value = var.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = "https://127.0.0.1:6443"
}

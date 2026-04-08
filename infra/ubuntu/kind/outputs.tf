output "kubeconfig_content" {
  description = "Kubeconfig for the kind cluster"
  value       = data.local_file.kubeconfig.content
  sensitive   = true
}

output "cluster_name" {
  value = var.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API endpoint"
  value       = "https://127.0.0.1:6443"
}

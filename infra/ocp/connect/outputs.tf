output "kubeconfig_content" {
  value     = local.kubeconfig
  sensitive = true
}

output "cluster_name" {
  value = var.cluster_name
}

output "cluster_endpoint" {
  value = var.api_server_url
}

output "kubeconfig_content" {
  description = "Kubeconfig for the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
}

output "cluster_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint"
  value       = azurerm_kubernetes_cluster.aks.kube_config[0].host
}

output "resource_group_name" {
  value = azurerm_resource_group.aks.name
}

output "cluster_id" {
  value = azurerm_kubernetes_cluster.aks.id
}

output "namespace" {
  value = var.namespace
}

output "deployment_name" {
  value = kubernetes_deployment_v1.client.metadata[0].name
}

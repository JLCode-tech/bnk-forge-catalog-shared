# bnk-forge-modules/app/demo-apps/outputs.tf

output "web_service_name" {
  description = "Name of the web frontend service"
  value       = kubernetes_service_v1.web.metadata[0].name
}

output "api_service_name" {
  description = "Name of the echo API service"
  value       = kubernetes_service_v1.api.metadata[0].name
}

output "backend_service_name" {
  description = "Name of the backend service"
  value       = kubernetes_service_v1.backend.metadata[0].name
}

output "apps_ready" {
  description = "Flag indicating all demo applications are deployed"
  value       = true
  depends_on = [
    kubernetes_deployment_v1.web,
    kubernetes_deployment_v1.api,
    kubernetes_deployment_v1.backend,
    kubernetes_service_v1.web,
    kubernetes_service_v1.api,
    kubernetes_service_v1.backend,
  ]
}

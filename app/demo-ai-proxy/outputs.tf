# bnk-forge-modules/app/demo-ai-proxy/outputs.tf

output "litellm_service_name" {
  description = "Name of the LiteLLM proxy service"
  value       = kubernetes_service_v1.litellm.metadata[0].name
}

output "litellm_service_port" {
  description = "Port of the LiteLLM proxy service"
  value       = 4000
}

output "prometheus_service_name" {
  description = "Name of the Prometheus service"
  value       = kubernetes_service_v1.prometheus.metadata[0].name
}

output "prometheus_endpoint" {
  description = "Full Prometheus endpoint URL (for F5BigAnalyzer dataSources)"
  value       = "http://prometheus-service.${var.app_namespace}.svc.cluster.local:9090"
}

output "ai_route_name" {
  description = "Name of the AI HTTPRoute (if created)"
  value       = var.enable_ai_route ? "ai-chat-route" : ""
}

output "ai_proxy_ready" {
  description = "Flag indicating AI proxy stack is deployed"
  value       = true
  depends_on  = [null_resource.verify_ai_proxy]
}

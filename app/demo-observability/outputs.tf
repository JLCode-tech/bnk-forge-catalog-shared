# bnk-forge-modules/app/demo-observability/outputs.tf

output "fluentbit_service_name" {
  description = "Name of the Fluent Bit HSL service"
  value       = kubernetes_service_v1.fluentbit.metadata[0].name
}

output "fluentbit_hsl_port" {
  description = "UDP port for HSL log ingestion"
  value       = var.fluentbit_hsl_port
}

output "loki_service_name" {
  description = "Name of the Loki service"
  value       = kubernetes_service_v1.loki.metadata[0].name
}

output "observability_ready" {
  description = "Flag indicating observability stack is deployed"
  value       = true
  depends_on = [
    kubernetes_deployment_v1.loki,
    kubernetes_deployment_v1.fluentbit,
    kubernetes_service_v1.loki,
    kubernetes_service_v1.fluentbit,
  ]
}

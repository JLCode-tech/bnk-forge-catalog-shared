# infrastructure-modules/bnk/f5biganalyzer/outputs.tf

output "analyzer_name" {
  description = "Name of the F5BigAnalyzer resource"
  value       = kubernetes_manifest.f5biganalyzer.manifest.metadata.name
}

output "analyzer_namespace" {
  description = "Namespace where analyzer is deployed"
  value       = kubernetes_manifest.f5biganalyzer.manifest.metadata.namespace
}

output "analyzer_ready" {
  description = "Flag indicating analyzer is ready"
  value       = true
  depends_on  = [null_resource.verify_analyzer]
}

output "metrics_endpoint" {
  description = "Metrics endpoint URL for monitoring"
  value       = var.enable_metrics ? "http://${var.analyzer_name}.${var.analyzer_namespace}:${var.metrics_port}/metrics" : null
}

output "routing_algorithm" {
  description = "Configured routing algorithm"
  value       = var.routing_algorithm
}

output "model_type" {
  description = "Configured LLM model type"
  value       = var.llm_workload_config.model_type
}

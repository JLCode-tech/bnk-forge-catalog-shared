# bnk-forge-modules/app/demo-ai-analyzer/outputs.tf

output "analyzer_name" {
  description = "Name of the F5BigAnalyzer CR"
  value       = "demo-bedrock-analyzer"
}

output "analyzer_script_configmap" {
  description = "Name of the ConfigMap containing the custom analyzer script"
  value       = kubernetes_config_map_v1.analyzer_script.metadata[0].name
}

output "token_irule_name" {
  description = "Name of the AI token counting iRule"
  value       = var.enable_token_irule ? "demo-ai-token-counter" : ""
}

output "ai_analyzer_ready" {
  description = "Flag indicating AI Analyzer is deployed"
  value       = true
  depends_on  = [null_resource.verify_analyzer]
}

# bnk-forge-modules/app/demo-irules/outputs.tf

output "token_counting_irule_name" {
  description = "Name of the token counting HSL iRule"
  value       = "genai-token-hsl-irule"
  depends_on  = [kubernetes_manifest.token_counting_irule]
}

output "smartllm_routing_irule_name" {
  description = "Name of the SmartLLM routing iRule (empty if disabled)"
  value       = var.enable_smart_listener ? "genai-llm-route-irule" : ""
}

output "netpolicy_names" {
  description = "Names of the BNK network policies created"
  value = compact([
    "token-hsl-standard-netpolicy",
    var.enable_smart_listener ? "smart-combined-netpolicy" : "",
  ])
}

output "irules_ready" {
  description = "Flag indicating iRules and network policies are deployed"
  value       = true
  depends_on  = [null_resource.verify_irules]
}

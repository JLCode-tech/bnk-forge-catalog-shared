# bnk-forge-modules/app/demo-irules/outputs.tf

output "irule_name" {
  description = "Name of the request logger iRule"
  value       = "demo-request-logger"
  depends_on  = [kubernetes_manifest.request_logger_irule]
}

output "hsl_publisher_name" {
  description = "Name of the HSL publisher"
  value       = "demo-hsl-publisher"
  depends_on  = [kubernetes_manifest.hsl_publisher]
}

output "netpolicy_names" {
  description = "Names of the BNK network policies created"
  value = compact([
    "demo-netpolicy-http",
    var.enable_https_listener ? "demo-netpolicy-https" : "",
    var.enable_smart_listener ? "demo-netpolicy-smart" : "",
  ])
}

output "irules_ready" {
  description = "Flag indicating iRules and network policies are deployed"
  value       = true
  depends_on  = [null_resource.verify_irules]
}

# infrastructure-modules/bnk/f5bigfwpolicy/outputs.tf

output "policy_name" {
  description = "Name of the F5BigFwPolicy resource"
  value       = kubernetes_manifest.f5bigfwpolicy.manifest.metadata.name
}

output "policy_namespace" {
  description = "Namespace where firewall policy is deployed"
  value       = kubernetes_manifest.f5bigfwpolicy.manifest.metadata.namespace
}

output "policy_ready" {
  description = "Flag indicating firewall policy is ready"
  value       = true
  depends_on  = [null_resource.verify_policy]
}

output "default_action" {
  description = "Default action for unmatched traffic"
  value       = var.default_action
}

output "ingress_rule_count" {
  description = "Number of ingress rules configured"
  value       = length(var.ingress_rules)
}

output "egress_rule_count" {
  description = "Number of egress rules configured"
  value       = length(var.egress_rules)
}

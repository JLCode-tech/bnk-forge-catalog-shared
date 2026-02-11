# bnk-forge-modules/app/demo-security/outputs.tf

output "fw_policy_name" {
  description = "Name of the firewall policy"
  value       = "demo-fw-policy"
  depends_on  = [kubernetes_manifest.fw_policy]
}

output "secpolicy_name" {
  description = "Name of the BNK security policy"
  value       = "demo-secpolicy"
  depends_on  = [kubernetes_manifest.secpolicy]
}

output "security_ready" {
  description = "Flag indicating security policies are deployed"
  value       = true
  depends_on  = [null_resource.verify_security]
}

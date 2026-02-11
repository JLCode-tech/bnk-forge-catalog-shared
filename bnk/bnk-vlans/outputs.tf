# bnk/bnk-vlans/outputs.tf

output "external_self_ips" {
  description = "External VLAN self IPs"
  value       = var.external_self_ips
}

output "internal_self_ips" {
  description = "Internal VLAN self IPs"
  value       = var.internal_self_ips
}

output "vlans_ready" {
  description = "Gate output — true when VLAN CRs are applied"
  value       = true

  depends_on = [null_resource.wait_for_programmed]
}

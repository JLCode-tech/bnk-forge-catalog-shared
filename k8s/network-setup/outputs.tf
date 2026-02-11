# k8s/network-setup/outputs.tf

output "external_nad_name" {
  description = "Name of the external network attachment definition"
  value       = "external-netdevice"
}

output "internal_nad_name" {
  description = "Name of the internal network attachment definition"
  value       = "internal-netdevice"
}

output "namespace" {
  description = "Namespace where NADs are deployed"
  value       = var.namespace
}

output "external_self_ips" {
  description = "Fixed external self IPs (one per AZ) — use these for VLAN CRs"
  value       = var.external_self_ips
}

output "internal_self_ips" {
  description = "Fixed internal self IPs (one per AZ) — use these for VLAN CRs"
  value       = var.internal_self_ips
}

output "external_subnet_cidrs" {
  description = "External subnet CIDRs (one per AZ)"
  value       = var.external_subnet_cidrs
}

output "internal_subnet_cidrs" {
  description = "Internal subnet CIDRs (one per AZ)"
  value       = var.internal_subnet_cidrs
}

output "nads_ready" {
  description = "Flag indicating NADs are created and ready"
  value       = true

  depends_on = [
    kubernetes_manifest.external_nad,
    kubernetes_manifest.internal_nad
  ]
}

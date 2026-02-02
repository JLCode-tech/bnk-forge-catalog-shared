# infrastructure-modules/bnk/f5spkvlan/outputs.tf

output "vlan_name" {
  description = "Name of the F5SPKVlan resource"
  value       = kubernetes_manifest.f5spkvlan.manifest.metadata.name
}

output "vlan_namespace" {
  description = "Namespace where VLAN is deployed"
  value       = kubernetes_manifest.f5spkvlan.manifest.metadata.namespace
}

output "vlan_ready" {
  description = "Flag indicating VLAN is ready"
  value       = true
  depends_on  = [null_resource.verify_vlan]
}

output "vlan_type" {
  description = "VLAN type (internal or external)"
  value       = var.internal ? "internal" : "external"
}

output "selfip_addresses" {
  description = "Configured self-IP addresses"
  value       = var.selfip_v4s
}

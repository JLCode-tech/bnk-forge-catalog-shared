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

output "tmm_data_plane_mode" {
  description = "TMM data-plane mode (kernel|sriov). Wire to cneinstance.tmm_data_plane_mode."
  value       = var.tmm_data_plane_mode
}

output "external_pci_bus_id" {
  description = "PCI bus ID of the external ENI. Wire to cneinstance.external_pci_bus_id."
  value       = var.external_pci_bus_id
}

output "internal_pci_bus_id" {
  description = "PCI bus ID of the internal ENI. Wire to cneinstance.internal_pci_bus_id."
  value       = var.internal_pci_bus_id
}

output "nads_ready" {
  description = "Flag indicating NADs are created and ready"
  value       = true

  depends_on = [
    kubernetes_manifest.external_nad,
    kubernetes_manifest.internal_nad
  ]
}

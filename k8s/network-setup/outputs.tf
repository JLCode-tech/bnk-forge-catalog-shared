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

output "nads_ready" {
  description = "Flag indicating NADs are created and ready"
  value       = true

  depends_on = [
    kubernetes_manifest.external_nad,
    kubernetes_manifest.internal_nad
  ]
}

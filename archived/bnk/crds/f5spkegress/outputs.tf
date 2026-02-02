# infrastructure-modules/bnk/f5spkegress/outputs.tf

output "egress_name" {
  description = "Name of the F5SPKEgress resource"
  value       = kubernetes_manifest.f5spkegress.manifest.metadata.name
}

output "egress_namespace" {
  description = "Namespace where egress config is deployed"
  value       = kubernetes_manifest.f5spkegress.manifest.metadata.namespace
}

output "egress_ready" {
  description = "Flag indicating egress configuration is ready"
  value       = true
  depends_on  = [null_resource.verify_egress]
}

output "egress_cidr" {
  description = "Configured egress CIDR range"
  value       = var.egress_cidr
}

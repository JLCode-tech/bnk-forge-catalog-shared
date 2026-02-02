# infrastructure-modules/bnk/referencegrant/outputs.tf

output "grant_name" {
  description = "Name of the ReferenceGrant resource"
  value       = kubernetes_manifest.referencegrant.manifest.metadata.name
}

output "grant_namespace" {
  description = "Namespace where grant is deployed"
  value       = kubernetes_manifest.referencegrant.manifest.metadata.namespace
}

output "grant_ready" {
  description = "Flag indicating grant is ready"
  value       = true
  depends_on  = [null_resource.verify_grant]
}

output "from_namespaces" {
  description = "Namespaces allowed to reference resources"
  value       = var.from_namespaces
}

output "to_resources" {
  description = "Resource types that can be referenced"
  value       = var.to_resources
}

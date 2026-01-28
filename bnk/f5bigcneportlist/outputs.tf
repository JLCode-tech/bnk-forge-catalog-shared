# infrastructure-modules/bnk/f5bigcneportlist/outputs.tf

output "list_name" {
  description = "Name of the F5BigCnePortlist resource"
  value       = kubernetes_manifest.f5bigcneportlist.manifest.metadata.name
}

output "list_namespace" {
  description = "Namespace where port list is deployed"
  value       = kubernetes_manifest.f5bigcneportlist.manifest.metadata.namespace
}

output "list_ready" {
  description = "Flag indicating port list is ready"
  value       = true
  depends_on  = [null_resource.verify_list]
}

output "port_count" {
  description = "Number of ports/ranges in the list"
  value       = length(var.ports)
}

# infrastructure-modules/bnk/f5bigcneaddresslist/outputs.tf

output "list_name" {
  description = "Name of the F5BigCneAddresslist resource"
  value       = kubernetes_manifest.f5bigcneaddresslist.manifest.metadata.name
}

output "list_namespace" {
  description = "Namespace where address list is deployed"
  value       = kubernetes_manifest.f5bigcneaddresslist.manifest.metadata.namespace
}

output "list_ready" {
  description = "Flag indicating address list is ready"
  value       = true
  depends_on  = [null_resource.verify_list]
}

output "address_count" {
  description = "Number of addresses in the list"
  value       = length(var.addresses)
}

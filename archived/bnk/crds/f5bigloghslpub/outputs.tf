# infrastructure-modules/bnk/f5bigloghslpub/outputs.tf

output "publisher_name" {
  description = "Name of the F5BigLogHslpub resource"
  value       = kubernetes_manifest.f5bigloghslpub.manifest.metadata.name
}

output "publisher_namespace" {
  description = "Namespace where HSL publisher is deployed"
  value       = kubernetes_manifest.f5bigloghslpub.manifest.metadata.namespace
}

output "publisher_ready" {
  description = "Flag indicating HSL publisher is ready"
  value       = true
  depends_on  = [null_resource.verify_publisher]
}

output "protocol" {
  description = "Configured syslog protocol"
  value       = var.protocol
}

output "server_count" {
  description = "Number of syslog servers configured"
  value       = length(var.syslog_servers)
}

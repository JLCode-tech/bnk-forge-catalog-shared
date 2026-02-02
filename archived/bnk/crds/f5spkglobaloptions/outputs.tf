# infrastructure-modules/bnk/f5spkglobaloptions/outputs.tf

output "options_name" {
  description = "Name of the F5SPKGlobalOptions resource"
  value       = kubernetes_manifest.f5spkglobaloptions.manifest.metadata.name
}

output "options_ready" {
  description = "Flag indicating global options are ready"
  value       = true
  depends_on  = [null_resource.verify_options]
}

output "crypto_acceleration_enabled" {
  description = "Whether crypto acceleration is enabled"
  value       = var.crypto_acceleration
}

output "hardware_offload_enabled" {
  description = "Whether hardware offload is enabled"
  value       = var.hardware_offload_enabled
}

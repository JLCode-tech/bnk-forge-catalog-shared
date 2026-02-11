# bnk/flo/outputs.tf

output "flo_namespace" {
  description = "Namespace where FLO is deployed"
  value       = var.flo_namespace
}

output "flo_ready" {
  description = "Gate output — true when FLO is deployed and verified"
  value       = true

  depends_on = [null_resource.verify_flo]
}

output "helm_release_name" {
  description = "Name of the FLO Helm release"
  value       = helm_release.flo.name
}

output "helm_release_version" {
  description = "Version of the FLO Helm chart"
  value       = helm_release.flo.version
}

output "license_mode" {
  description = "License operation mode"
  value       = var.license_mode
}

output "crds_installed" {
  description = "Gate output — true when FLO CRDs are installed"
  value       = true

  depends_on = [null_resource.verify_flo]
}

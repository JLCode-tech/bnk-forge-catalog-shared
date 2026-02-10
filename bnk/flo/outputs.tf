# bnk/flo/outputs.tf

output "flo_namespace" {
  description = "Namespace where FLO is deployed"
  value       = data.kubernetes_namespace_v1.flo.metadata[0].name
}

output "ipam_namespace" {
  description = "Namespace where IPAM operator is deployed"
  value       = var.enable_ipam_operator && var.ipam_namespace != var.flo_namespace ? data.kubernetes_namespace_v1.ipam[0].metadata[0].name : var.ipam_namespace
}

output "flo_ready" {
  description = "Flag indicating FLO is ready for dependent modules"
  value       = true
  depends_on  = [null_resource.verify_flo]
}

output "helm_release_name" {
  description = "Name of the FLO Helm release"
  value       = helm_release.flo.name
}

output "helm_release_version" {
  description = "Version of the FLO Helm chart deployed"
  value       = helm_release.flo.version
}

output "license_mode" {
  description = "Licensing mode configured for FLO"
  value       = var.license_mode
}

output "crds_installed" {
  description = "Flag indicating CRDs are installed by FLO"
  value       = true
  depends_on  = [null_resource.verify_flo]
}

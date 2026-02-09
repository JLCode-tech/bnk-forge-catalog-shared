# k8s/cert-manager/outputs.tf
# Jetstack cert-manager outputs for BNK 2.2 GA

output "release_name" {
  description = "Name of the Helm release"
  value       = helm_release.cert_manager.name
}

output "release_status" {
  description = "Status of the Helm release"
  value       = helm_release.cert_manager.status
}

output "namespace" {
  description = "Namespace where cert-manager is deployed"
  value       = helm_release.cert_manager.namespace
}

output "chart_version" {
  description = "Version of the deployed cert-manager chart"
  value       = helm_release.cert_manager.version
}

output "cert_manager_ready" {
  description = "Indicates cert-manager deployment is complete"
  value       = true
  depends_on  = [null_resource.verify_cert_manager]
}

# =============================================================================
# CLUSTER ISSUER OUTPUTS
# =============================================================================
# These are used by FLO and CNEInstance configuration

output "cluster_issuer_name" {
  description = "Name of the CA ClusterIssuer for BNK certificates (use in FLO flo-values.yaml and CNEInstance)"
  value       = var.create_cluster_issuer ? var.cluster_issuer_name : ""
}

output "ca_secret_name" {
  description = "Name of the CA certificate secret"
  value       = var.create_cluster_issuer ? var.ca_certificate_name : ""
}

output "webhook_service_name" {
  description = "Name of the cert-manager webhook service"
  value       = "${var.release_name}-webhook"
}

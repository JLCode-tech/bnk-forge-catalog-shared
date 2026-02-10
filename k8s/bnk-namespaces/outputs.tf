# k8s/bnk-namespaces/outputs.tf
# BNK Namespaces Module Outputs

output "bnk_namespace" {
  description = "Name of the BNK data plane namespace (TMM pods)"
  value       = kubernetes_namespace_v1.f5_bnk.metadata[0].name
}

output "operator_namespace" {
  description = "Name of the BNK operator namespace (FLO, CNE controller, CWC)"
  value       = kubernetes_namespace_v1.f5_operator.metadata[0].name
}

output "utils_namespace" {
  description = "Name of the utilities namespace (IPAM, observability, dSSM)"
  value       = kubernetes_namespace_v1.f5_utils.metadata[0].name
}

output "gateway_namespace" {
  description = "Name of the gateway namespace (for Gateway API resources)"
  value       = var.create_gateway_namespace ? kubernetes_namespace_v1.gateway[0].metadata[0].name : var.gateway_namespace
}

output "namespaces_ready" {
  description = "Flag indicating all namespaces are created and ready"
  value       = true

  depends_on = [
    kubernetes_namespace_v1.f5_bnk,
    kubernetes_namespace_v1.f5_operator,
    kubernetes_namespace_v1.f5_utils,
    kubernetes_namespace_v1.gateway
  ]
}

output "far_secret_name" {
  description = "Name of the FAR image pull secret (if created)"
  value       = var.create_far_secrets ? var.far_secret_name : ""
}

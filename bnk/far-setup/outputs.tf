# bnk/far-setup/outputs.tf
# F5 BIG-IP Next for Kubernetes (BNK) 2.2 - FAR Setup Outputs

# =============================================================================
# NAMESPACE OUTPUTS
# =============================================================================

output "bnk_namespace" {
  description = "BNK controller namespace name"
  value       = local.effective_namespace
}

# Backward compatibility alias
output "spk_namespace" {
  description = "DEPRECATED: Use bnk_namespace instead"
  value       = local.effective_namespace
}

output "utils_namespace" {
  description = "F5 utils namespace name"
  value       = var.utils_namespace
}

output "namespaces" {
  description = "All namespaces with FAR secrets"
  value = {
    bnk   = local.effective_namespace
    utils = var.utils_namespace
  }
}

# =============================================================================
# FAR AUTHENTICATION OUTPUTS
# =============================================================================

output "image_pull_secrets" {
  description = "ImagePullSecrets configuration for Helm charts"
  value = [
    {
      name = "far-secret"
    }
  ]
}

output "far_secret_name" {
  description = "Name of the FAR authentication secret"
  value       = "far-secret"
}

output "far_secrets_created" {
  description = "List of namespaces where FAR secrets were created"
  value       = [local.effective_namespace, var.utils_namespace]
}

# =============================================================================
# COMPONENT VERSION OUTPUTS
# =============================================================================

output "component_versions" {
  description = "All component versions parsed from manifest"
  value       = data.external.component_versions.result
}

output "crds_versions" {
  description = "CRD component versions"
  value = {
    common        = lookup(data.external.component_versions.result, "spk_crds_common", "")
    service_proxy = lookup(data.external.component_versions.result, "spk_crds_service_proxy", "")
    deprecated    = lookup(data.external.component_versions.result, "spk_crds_deprecated", "")
  }
}

output "cert_manager_version" {
  description = "F5 Certificate Manager version"
  value       = lookup(data.external.component_versions.result, "cert_manager", "")
}

output "flo_version" {
  description = "F5 Lifecycle Operator version"
  value       = lookup(data.external.component_versions.result, "flo", "")
}

output "cwc_version" {
  description = "Cluster Wide Controller version"
  value       = lookup(data.external.component_versions.result, "cwc", "")
}

output "controller_version" {
  description = "F5 Ingress Controller version"
  value       = lookup(data.external.component_versions.result, "f5ingress", "")
}

output "rabbitmq_version" {
  description = "RabbitMQ version"
  value       = lookup(data.external.component_versions.result, "rabbitmq", "")
}

output "fluentd_version" {
  description = "F5 TODA Fluentd version"
  value       = lookup(data.external.component_versions.result, "fluentd", "")
}

output "dssm_version" {
  description = "Distributed Session State Management version"
  value       = lookup(data.external.component_versions.result, "dssm", "")
}

output "observer_version" {
  description = "F5 TODA Observer version"
  value       = lookup(data.external.component_versions.result, "observer", "")
}

# =============================================================================
# MANIFEST OUTPUTS
# =============================================================================

output "manifest_version" {
  description = "BNK manifest version used"
  value       = local.effective_manifest_version
}

output "manifest_file_path" {
  description = "Path to downloaded manifest file"
  value       = data.external.manifest_download.result.manifest_file
}

# =============================================================================
# DEPENDENCY OUTPUTS
# =============================================================================

output "dependencies_ready" {
  description = "Indicates all FAR setup dependencies are ready"
  value = {
    far_secrets_created = true
    manifest_downloaded = data.external.manifest_download.result.success == "true"
    versions_parsed     = length(keys(data.external.component_versions.result)) > 0
  }
}

output "setup_complete" {
  description = "Boolean indicating if FAR setup is complete"
  value = alltrue([
    data.external.manifest_download.result.success == "true",
    length(keys(data.external.component_versions.result)) > 0,
  ])
}

# =============================================================================
# HELM CHART REPOSITORY OUTPUTS
# =============================================================================

output "helm_repository" {
  description = "F5 Helm repository configuration"
  value = {
    url    = "oci://repo.f5.com"
    secret = "far-secret"
  }
}

output "docker_registry" {
  description = "F5 Docker registry configuration"
  value = {
    url    = "repo.f5.com"
    secret = "far-secret"
  }
}

# bnk/flo/variables.tf
# F5 Lifecycle Operator Module Variables

# =============================================================================
# CLUSTER / NAMESPACE
# =============================================================================

variable "cluster_name" {
  description = "Name of the Kubernetes cluster (auto-wired)"
  type        = string
  default     = ""
}

variable "flo_namespace" {
  description = "Namespace for FLO (wired from prerequisites.operator_namespace)"
  type        = string
  default     = "f5-operator"
}

# =============================================================================
# FLO VERSION AND DEPENDENCIES (wired from prerequisites)
# =============================================================================

variable "flo_version" {
  description = "FLO Helm chart version (wired from prerequisites.flo_version)"
  type        = string
  default     = "v1.198.4-0.1.36"
}

variable "far_secret_name" {
  description = "Name of the FAR pull secret (wired from prerequisites.far_secret_name)"
  type        = string
  default     = "far-secret"
}

# =============================================================================
# LICENSING
# =============================================================================

variable "jwt_token" {
  description = "JWT token for F5 licensing (injected as project secret)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "license_mode" {
  description = "License mode: connected or f5licenseproxy"
  type        = string
  default     = "connected"

  validation {
    condition     = contains(["connected", "f5licenseproxy"], var.license_mode)
    error_message = "License mode must be either 'connected' or 'f5licenseproxy'"
  }
}

variable "license_environment" {
  description = "Licensing environment: production or test"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["production", "test"], var.license_environment)
    error_message = "license_environment must be either 'production' or 'test'"
  }
}

variable "f5_license_proxy_url" {
  description = "F5 License Proxy URL (for f5licenseproxy mode)"
  type        = string
  default     = ""
}

# =============================================================================
# CERTIFICATE CONFIGURATION (wired from cert-manager)
# =============================================================================

variable "cluster_issuer_name" {
  description = "ClusterIssuer name (wired from cert-manager.cluster_issuer_name)"
  type        = string
  default     = "bnk-ca-cluster-issuer"
}

variable "cert_manager_ready" {
  description = "Dependency gate from cert-manager module"
  type        = bool
  default     = true
}

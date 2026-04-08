# k8s/bnk-prerequisites/variables.tf
# BNK Prerequisites Module Variables

# =============================================================================
# PLATFORM KUBECONFIG (injected by BNK-Forge or set manually)
# =============================================================================

variable "forge_kubeconfig_content" {
  description = "Kubeconfig YAML content. Automatically injected by BNK-Forge for any platform (EKS, AKS, GKE, OCP, generic). Set manually for standalone usage."
  type        = string
  default     = ""
  sensitive   = true
}

# =============================================================================
# REQUIRED — Injected as Project Secret
# =============================================================================

variable "cne_pull_secret" {
  description = "Base64-encoded F5 FAR service account key JSON content. Injected as a project secret."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.cne_pull_secret) > 0
    error_message = "cne_pull_secret must not be empty. Configure it as a project secret."
  }
}

# =============================================================================
# NAMESPACE CONFIGURATION
# =============================================================================

variable "operator_namespace" {
  description = "Namespace for FLO and ALL BNK components (CNEInstance deploys everything here)"
  type        = string
  default     = "f5-operator"
}

variable "utils_namespace" {
  description = "Namespace for utility components (IPAM if deployed separately)"
  type        = string
  default     = "f5-utils"
}

variable "gateway_namespace" {
  description = "Namespace for Gateway API resources (Gateway, HTTPRoute, etc.)"
  type        = string
  default     = "gateway-ns"
}

# =============================================================================
# BNK MANIFEST VERSION
# =============================================================================

variable "bnk_manifest_version" {
  description = "BNK manifest version to download from FAR (e.g., 2.2.0-3.2226.0-0.0.385)"
  type        = string
  default     = "2.2.0-3.2226.0-0.0.385"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+-", var.bnk_manifest_version))
    error_message = "BNK manifest version must start with X.Y.Z- format"
  }
}

# =============================================================================
# CLUSTER IDENTIFICATION (auto-wired)
# =============================================================================

variable "cluster_name" {
  description = "Name of the Kubernetes cluster (auto-wired from EKS module)"
  type        = string
  default     = ""
}

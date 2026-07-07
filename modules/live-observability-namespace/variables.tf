# =============================================================================
# Forge-injected kubeconfig
# =============================================================================
# local.forge_kubeconfig is injected at deploy time via a generated
# bnk_forge_providers.tf. Falls back to forge_kubeconfig_content for
# unit / local testing.

variable "forge_kubeconfig_content" {
  description = "Plain-text kubeconfig used for kubectl applies. Forge overrides this at deploy time with a local.forge_kubeconfig reference. Sensitive."
  type        = string
  sensitive   = true
  default     = ""
}

# =============================================================================
# Namespace configuration
# =============================================================================

variable "observability_namespace" {
  description = "Name of the Kubernetes namespace to create for live observability components. Default 'llm-egress' matches Forge AI Gateway observability defaults (PR #393)."
  type        = string
  default     = "llm-egress"
}

variable "poc_label" {
  description = "Value for the bnk-forge/poc label added to the namespace. Useful for grouping and cleanup in multi-tenant clusters."
  type        = string
  default     = "default"
}

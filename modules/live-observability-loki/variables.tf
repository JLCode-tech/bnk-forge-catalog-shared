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
# Loki configuration
# =============================================================================

variable "observability_namespace" {
  description = "Namespace where Loki is deployed. Must match the namespace created by live-observability-namespace."
  type        = string
  default     = "llm-egress"
}

variable "loki_service_name" {
  description = "Kubernetes Service name for Loki. Must match the Forge AI Gateway loki_service_name setting (default: loki)."
  type        = string
  default     = "loki"
}

variable "loki_port" {
  description = "Port on which Loki's HTTP API listens. Must match the Forge AI Gateway loki_port setting (default: 3100)."
  type        = number
  default     = 3100
}

variable "loki_retention_hours" {
  description = "Loki chunk and index retention in hours. Default 24 (1 day) is suitable for PoC. Set to 168 (7 days) if you need a longer rolling window."
  type        = number
  default     = 24
}

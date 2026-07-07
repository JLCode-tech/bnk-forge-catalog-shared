# =============================================================================
# Forge-injected kubeconfig
# =============================================================================

variable "forge_kubeconfig_content" {
  description = "Plain-text kubeconfig used for kubectl calls. Forge overrides this at deploy time with a local.forge_kubeconfig reference. Sensitive."
  type        = string
  sensitive   = true
  default     = ""
}

# =============================================================================
# Readiness probe configuration
# =============================================================================

variable "observability_namespace" {
  description = "Namespace where Loki is running. Forge auto-wires this from live-observability-namespace output."
  type        = string
  default     = "llm-egress"
}

variable "loki_service_name" {
  description = "Loki Kubernetes Service name. Forge auto-wires this from live-observability-loki output."
  type        = string
  default     = "loki"
}

variable "loki_port" {
  description = "Loki HTTP port. Must match the value configured in live-observability-loki."
  type        = number
  default     = 3100
}

variable "readiness_timeout_seconds" {
  description = "Total seconds to poll for a Loki /ready 200 response via the K8s API-server service proxy."
  type        = number
  default     = 120
}

# =============================================================================
# Forge-injected kubeconfig
# =============================================================================

variable "forge_kubeconfig_content" {
  description = "Plain-text kubeconfig used for kubectl applies. Forge overrides this at deploy time with a local.forge_kubeconfig reference. Sensitive."
  type        = string
  sensitive   = true
  default     = ""
}

# =============================================================================
# Collector configuration
# =============================================================================

variable "observability_namespace" {
  description = "Namespace where Fluent Bit resources are deployed. Forge auto-wires this from live-observability-namespace output."
  type        = string
  default     = "llm-egress"
}

variable "loki_service_name" {
  description = "Kubernetes Service name for Loki. Used to construct the in-cluster DNS hostname (<svc>.<ns>.svc.cluster.local). Forge auto-wires this from live-observability-loki output loki_service_name."
  type        = string
  default     = "loki"
}

variable "loki_port" {
  description = "Loki HTTP API port. Forge auto-wires this from live-observability-loki output loki_port."
  type        = number
  default     = 3100
}

variable "enable_pod_log_collection" {
  description = "When true, deploy the Fluent Bit DaemonSet. Set false to skip (useful if the cluster already has a log collector or you only need direct-push producers)."
  type        = bool
  default     = true
}

variable "fluent_bit_version" {
  description = "Fluent Bit container image tag. Default is a stable production release tested with Loki 2.9.x."
  type        = string
  default     = "3.1.9"
}

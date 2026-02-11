# bnk-forge-modules/app/demo-observability/variables.tf

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = ""
}

variable "observability_namespace" {
  description = "Namespace for observability components"
  type        = string
  default     = "observability"
}

variable "loki_retention_days" {
  description = "Number of days to retain logs in Loki"
  type        = number
  default     = 7

  validation {
    condition     = var.loki_retention_days >= 1 && var.loki_retention_days <= 90
    error_message = "Retention must be between 1 and 90 days."
  }
}

variable "fluentbit_hsl_port" {
  description = "UDP port for Fluent Bit HSL receiver"
  type        = number
  default     = 5514
}

# Dependency input
variable "namespaces_ready" {
  description = "Flag from demo-namespace module indicating namespaces are ready"
  type        = bool
}

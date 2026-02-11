# bnk-forge-modules/app/demo-apps/variables.tf

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = ""
}

variable "app_namespace" {
  description = "Namespace for demo application workloads"
  type        = string
  default     = "demo-apps"
}

variable "web_replicas" {
  description = "Number of web frontend replicas"
  type        = number
  default     = 2

  validation {
    condition     = var.web_replicas >= 1 && var.web_replicas <= 10
    error_message = "Web replicas must be between 1 and 10."
  }
}

variable "api_replicas" {
  description = "Number of echo API replicas"
  type        = number
  default     = 2

  validation {
    condition     = var.api_replicas >= 1 && var.api_replicas <= 10
    error_message = "API replicas must be between 1 and 10."
  }
}

variable "backend_replicas" {
  description = "Number of backend service replicas"
  type        = number
  default     = 1

  validation {
    condition     = var.backend_replicas >= 1 && var.backend_replicas <= 10
    error_message = "Backend replicas must be between 1 and 10."
  }
}

# Dependency input
variable "namespaces_ready" {
  description = "Flag from demo-namespace module indicating namespaces are ready"
  type        = bool
}

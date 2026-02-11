# bnk-forge-modules/app/demo-namespace/variables.tf

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = ""
}

variable "app_namespace" {
  description = "Namespace for demo application workloads"
  type        = string
  default     = "demo-apps"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.app_namespace))
    error_message = "Namespace must be a valid Kubernetes namespace name."
  }
}

variable "gateway_namespace" {
  description = "Namespace for BNK Gateway and routing resources"
  type        = string
  default     = "bnk-gw"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.gateway_namespace))
    error_message = "Namespace must be a valid Kubernetes namespace name."
  }
}

variable "observability_namespace" {
  description = "Namespace for Fluent Bit and Loki observability stack"
  type        = string
  default     = "observability"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.observability_namespace))
    error_message = "Namespace must be a valid Kubernetes namespace name."
  }
}

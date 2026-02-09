# infrastructure-modules/bnk/cneinstance/variables.tf
# CneInstance Module Variables - CNE Instance Configuration

# =============================================================================
# REQUIRED VARIABLES
# =============================================================================

variable "cluster_name" {
  description = "Name of the Kubernetes cluster (used for resource naming and identification)"
  type        = string
}

variable "instance_name" {
  description = "Name of the CneInstance resource"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.instance_name))
    error_message = "Instance name must be valid Kubernetes resource name"
  }
}

variable "instance_namespace" {
  description = "Namespace where CNE instance will be deployed"
  type        = string
}

variable "instance_config" {
  description = "CNE instance configuration settings"
  type = object({
    instance_type = optional(string, "standard")
    replicas      = optional(number, 1)
    affinity      = optional(map(any), {})
  })
}

# =============================================================================
# OPTIONAL VARIABLES
# =============================================================================

variable "resource_limits" {
  description = "Resource limits for CNE instance"
  type = object({
    cpu_request    = optional(string, "500m")
    cpu_limit      = optional(string, "2000m")
    memory_request = optional(string, "1Gi")
    memory_limit   = optional(string, "4Gi")
  })
  default = {}
}

# =============================================================================
# DEPENDENCY INPUTS
# =============================================================================

variable "flo_ready" {
  description = "Dependency flag indicating FLO is ready and CRDs are installed"
  type        = bool
}

# =============================================================================
# TAGS AND LABELS
# =============================================================================

variable "common_labels" {
  description = "Common labels to apply to all Kubernetes resources"
  type        = map(string)
  default     = {}
}

variable "annotations" {
  description = "Annotations to add to the CNE instance resource"
  type        = map(string)
  default     = {}
}

# infrastructure-modules/bnk/f5spksnatpool/variables.tf
# F5SPKSnatpool Module Variables - SNAT Pool Configuration

# =============================================================================
# REQUIRED VARIABLES
# =============================================================================

variable "cluster_name" {
  description = "Name of the Kubernetes cluster (used for resource naming and identification)"
  type        = string
}

variable "pool_name" {
  description = "Name of the F5SPKSnatpool resource"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.pool_name))
    error_message = "Pool name must be valid Kubernetes resource name"
  }
}

variable "pool_namespace" {
  description = "Namespace where SNAT pool will be deployed"
  type        = string
}

variable "ip_ranges" {
  description = "List of IP addresses or ranges for SNAT pool (e.g., '10.0.1.10-10.0.1.20' or '10.0.1.10')"
  type        = list(string)

  validation {
    condition     = length(var.ip_ranges) > 0
    error_message = "At least one IP range must be provided"
  }
}

# =============================================================================
# OPTIONAL VARIABLES
# =============================================================================

variable "pool_members" {
  description = "Specific IP addresses for pool members"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for ip in var.pool_members :
      can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}$", ip))
    ])
    error_message = "All pool members must be valid IP addresses"
  }
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
  description = "Annotations to add to the SNAT pool resource"
  type        = map(string)
  default     = {}
}

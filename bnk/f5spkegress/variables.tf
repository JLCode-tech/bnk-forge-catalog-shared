# infrastructure-modules/bnk/f5spkegress/variables.tf
# F5SPKEgress Module Variables - Egress Traffic Configuration

# =============================================================================
# REQUIRED VARIABLES
# =============================================================================

variable "cluster_name" {
  description = "Name of the Kubernetes cluster (used for resource naming and identification)"
  type        = string
}

variable "egress_name" {
  description = "Name of the F5SPKEgress resource"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.egress_name))
    error_message = "Egress name must be valid Kubernetes resource name"
  }
}

variable "egress_namespace" {
  description = "Namespace where egress configuration will be deployed"
  type        = string
}

variable "egress_cidr" {
  description = "CIDR range for egress traffic"
  type        = string

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.egress_cidr))
    error_message = "Egress CIDR must be valid CIDR notation"
  }
}

# =============================================================================
# OPTIONAL VARIABLES
# =============================================================================

variable "snat_pool_ref" {
  description = "Reference to F5SPKSnatpool resource for source NAT"
  type        = string
  default     = null
}

variable "allowed_destinations" {
  description = "List of allowed destination CIDR ranges"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for cidr in var.allowed_destinations :
      can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", cidr))
    ])
    error_message = "All allowed destinations must be valid CIDR notation"
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
  description = "Annotations to add to the egress resource"
  type        = map(string)
  default     = {}
}

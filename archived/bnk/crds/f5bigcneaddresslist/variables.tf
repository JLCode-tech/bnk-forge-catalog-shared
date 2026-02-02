# infrastructure-modules/bnk/f5bigcneaddresslist/variables.tf
# F5BigCneAddresslist Module Variables - IP Address Lists

# =============================================================================
# REQUIRED VARIABLES
# =============================================================================

variable "cluster_name" {
  description = "Name of the Kubernetes cluster (used for resource naming and identification)"
  type        = string
}

variable "list_name" {
  description = "Name of the F5BigCneAddresslist resource"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.list_name))
    error_message = "List name must be valid Kubernetes resource name"
  }
}

variable "list_namespace" {
  description = "Namespace where address list will be deployed"
  type        = string
}

variable "addresses" {
  description = "List of IP addresses or CIDR ranges"
  type        = list(string)

  validation {
    condition     = length(var.addresses) > 0
    error_message = "At least one address must be provided"
  }

  validation {
    condition = alltrue([
      for addr in var.addresses :
      can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}(/[0-9]{1,2})?$", addr))
    ])
    error_message = "All addresses must be valid IP addresses or CIDR notation"
  }
}

# =============================================================================
# OPTIONAL VARIABLES
# =============================================================================

variable "description" {
  description = "Description of the address list"
  type        = string
  default     = ""
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
  description = "Annotations to add to the address list resource"
  type        = map(string)
  default     = {}
}

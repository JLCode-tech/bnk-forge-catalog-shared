# infrastructure-modules/bnk/f5bigcneportlist/variables.tf
# F5BigCnePortlist Module Variables - Port Lists

# =============================================================================
# REQUIRED VARIABLES
# =============================================================================

variable "cluster_name" {
  description = "Name of the Kubernetes cluster (used for resource naming and identification)"
  type        = string
}

variable "list_name" {
  description = "Name of the F5BigCnePortlist resource"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.list_name))
    error_message = "List name must be valid Kubernetes resource name"
  }
}

variable "list_namespace" {
  description = "Namespace where port list will be deployed"
  type        = string
}

variable "ports" {
  description = "List of ports or port ranges (e.g., '80', '443', '8000-8999')"
  type        = list(string)

  validation {
    condition     = length(var.ports) > 0
    error_message = "At least one port must be provided"
  }

  validation {
    condition = alltrue([
      for port in var.ports :
      can(regex("^([0-9]{1,5})(-[0-9]{1,5})?$", port))
    ])
    error_message = "All ports must be valid port numbers or ranges (e.g., '80', '443', '8000-8999')"
  }
}

# =============================================================================
# OPTIONAL VARIABLES
# =============================================================================

variable "description" {
  description = "Description of the port list"
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
  description = "Annotations to add to the port list resource"
  type        = map(string)
  default     = {}
}

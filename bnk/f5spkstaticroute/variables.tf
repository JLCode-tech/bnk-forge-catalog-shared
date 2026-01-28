# infrastructure-modules/bnk/f5spkstaticroute/variables.tf
# F5SPKStaticRoute Module Variables - Static Route Configuration

# =============================================================================
# REQUIRED VARIABLES
# =============================================================================

variable "cluster_name" {
  description = "Name of the Kubernetes cluster (used for resource naming and identification)"
  type        = string
}

variable "route_name" {
  description = "Name of the F5SPKStaticRoute resource"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.route_name))
    error_message = "Route name must be valid Kubernetes resource name"
  }
}

variable "route_namespace" {
  description = "Namespace where static route will be deployed"
  type        = string
}

variable "destination" {
  description = "Destination network in CIDR notation"
  type        = string

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.destination))
    error_message = "Destination must be valid CIDR notation"
  }
}

variable "gateway" {
  description = "Gateway IP address"
  type        = string

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}$", var.gateway))
    error_message = "Gateway must be valid IP address"
  }
}

# =============================================================================
# OPTIONAL VARIABLES
# =============================================================================

variable "interface" {
  description = "Network interface for the route"
  type        = string
  default     = null
}

variable "metric" {
  description = "Route metric/priority (lower is preferred)"
  type        = number
  default     = 1

  validation {
    condition     = var.metric >= 1 && var.metric <= 255
    error_message = "Metric must be between 1 and 255"
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
  description = "Annotations to add to the static route resource"
  type        = map(string)
  default     = {}
}

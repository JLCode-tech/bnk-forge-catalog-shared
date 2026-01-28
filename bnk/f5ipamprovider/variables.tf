# infrastructure-modules/bnk/f5ipamprovider/variables.tf
# F5IPAMProvider Module Variables - IP Address Management

# =============================================================================
# REQUIRED VARIABLES
# =============================================================================

variable "cluster_name" {
  description = "Name of the Kubernetes cluster (used for resource naming and identification)"
  type        = string
}

variable "provider_name" {
  description = "Name of the F5IPAMProvider resource"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.provider_name))
    error_message = "Provider name must be valid Kubernetes resource name"
  }
}

variable "provider_namespace" {
  description = "Namespace where IPAM provider will be deployed"
  type        = string
}

variable "ip_ranges" {
  description = "List of IP ranges for IPAM (CIDR notation or range format like 10.0.1.10-10.0.1.20)"
  type        = list(string)

  validation {
    condition     = length(var.ip_ranges) > 0
    error_message = "At least one IP range must be specified"
  }
}

# =============================================================================
# OPTIONAL VARIABLES
# =============================================================================

variable "provider_type" {
  description = "IPAM provider type (infoblox, f5-ipam, external)"
  type        = string
  default     = "f5-ipam"

  validation {
    condition     = contains(["infoblox", "f5-ipam", "external"], var.provider_type)
    error_message = "Provider type must be infoblox, f5-ipam, or external"
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
  description = "Annotations to add to the IPAM provider resource"
  type        = map(string)
  default     = {}
}

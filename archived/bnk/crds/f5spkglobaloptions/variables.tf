# infrastructure-modules/bnk/f5spkglobaloptions/variables.tf
# F5SPKGlobalOptions Module Variables - Cluster-Wide SPK Configuration

# =============================================================================
# REQUIRED VARIABLES
# =============================================================================

variable "cluster_name" {
  description = "Name of the Kubernetes cluster (used for resource naming and identification)"
  type        = string
}

variable "options_name" {
  description = "Name of the F5SPKGlobalOptions resource"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.options_name))
    error_message = "Options name must be valid Kubernetes resource name"
  }
}

# =============================================================================
# OPTIONAL VARIABLES
# =============================================================================

variable "crypto_acceleration" {
  description = "Enable crypto hardware acceleration"
  type        = bool
  default     = true
}

variable "hardware_offload_enabled" {
  description = "Enable hardware offload for network operations"
  type        = bool
  default     = true
}

variable "hardware_offload_settings" {
  description = "Hardware offload configuration options"
  type = object({
    tcp_offload       = optional(bool, true)
    checksum_offload  = optional(bool, true)
    segmentation      = optional(bool, true)
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
  description = "Annotations to add to the global options resource"
  type        = map(string)
  default     = {}
}

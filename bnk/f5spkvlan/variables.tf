# infrastructure-modules/bnk/f5spkvlan/variables.tf
# F5SPKVlan Module Variables - VLAN Configuration

# =============================================================================
# REQUIRED VARIABLES
# =============================================================================

variable "cluster_name" {
  description = "Name of the Kubernetes cluster (used for resource naming and identification)"
  type        = string
}

variable "vlan_name" {
  description = "Name of the F5SPKVlan resource"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.vlan_name))
    error_message = "VLAN name must be valid Kubernetes resource name"
  }
}

variable "vlan_namespace" {
  description = "Namespace where VLAN will be deployed"
  type        = string
}

variable "vlan_tag_name" {
  description = "VLAN tag name (used in F5 configuration)"
  type        = string
}

variable "interfaces" {
  description = "List of network interfaces (e.g., ['1.1', '1.2'])"
  type        = list(string)

  validation {
    condition     = length(var.interfaces) > 0
    error_message = "At least one interface must be specified"
  }
}

variable "selfip_v4s" {
  description = "List of IPv4 self-IP addresses"
  type        = list(string)

  validation {
    condition     = length(var.selfip_v4s) > 0
    error_message = "At least one self-IP address must be specified"
  }

  validation {
    condition = alltrue([
      for ip in var.selfip_v4s :
      can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}$", ip))
    ])
    error_message = "All self-IP addresses must be valid IPv4 addresses"
  }
}

variable "prefixlen_v4" {
  description = "IPv4 prefix length (CIDR notation)"
  type        = number

  validation {
    condition     = var.prefixlen_v4 >= 1 && var.prefixlen_v4 <= 32
    error_message = "Prefix length must be between 1 and 32"
  }
}

variable "internal" {
  description = "Whether VLAN is internal (true) or external (false)"
  type        = bool
}

# =============================================================================
# OPTIONAL VARIABLES
# =============================================================================

variable "vlan_id" {
  description = "VLAN ID (802.1Q tag)"
  type        = number
  default     = null

  validation {
    condition     = var.vlan_id == null || (var.vlan_id >= 1 && var.vlan_id <= 4094)
    error_message = "VLAN ID must be between 1 and 4094"
  }
}

variable "mtu" {
  description = "Maximum Transmission Unit"
  type        = number
  default     = 1500

  validation {
    condition     = var.mtu >= 576 && var.mtu <= 9000
    error_message = "MTU must be between 576 and 9000"
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
  description = "Annotations to add to the VLAN resource"
  type        = map(string)
  default     = {}
}

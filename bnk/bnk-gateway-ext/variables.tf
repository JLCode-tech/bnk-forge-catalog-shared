# bnk-forge-modules/bnk/bnk-gateway-ext/variables.tf
# F5BnkGateway Module Variables - IPAM Integration for Gateway API (F5 BNK 2.2 GA)

# =============================================================================
# REQUIRED VARIABLES
# =============================================================================

variable "gateway_ext_name" {
  description = "Name for the F5BnkGateway resource"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.gateway_ext_name))
    error_message = "Name must be valid Kubernetes resource name"
  }
}

variable "namespace" {
  description = "Namespace for the F5BnkGateway"
  type        = string
  default     = "default"
}

# =============================================================================
# IPAM CONFIGURATION
# =============================================================================

variable "ipv4_cidr_range" {
  description = "IPv4 CIDR range for IPAM allocation (e.g., 192.168.17.0/24)"
  type        = string
  default     = ""

  validation {
    condition     = var.ipv4_cidr_range == "" || can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.ipv4_cidr_range))
    error_message = "IPv4 CIDR must be valid notation (e.g., 192.168.17.0/24)"
  }
}

variable "ipv6_cidr_range" {
  description = "IPv6 CIDR range for IPAM allocation"
  type        = string
  default     = ""
}

variable "default_network" {
  description = "Default network name for IP allocation"
  type        = string
  default     = "default"
}

# =============================================================================
# DEPENDENCY INPUTS
# =============================================================================

variable "flo_ready" {
  description = "Dependency flag - FLO must be ready before applying"
  type        = bool
  default     = true
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
  description = "Annotations to add to the resource"
  type        = map(string)
  default     = {}
}

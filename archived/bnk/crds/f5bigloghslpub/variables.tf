# infrastructure-modules/bnk/f5bigloghslpub/variables.tf
# F5BigLogHslpub Module Variables - High-Speed Logging Publisher

# =============================================================================
# REQUIRED VARIABLES
# =============================================================================

variable "cluster_name" {
  description = "Name of the Kubernetes cluster (used for resource naming and identification)"
  type        = string
}

variable "publisher_name" {
  description = "Name of the F5BigLogHslpub resource"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.publisher_name))
    error_message = "Publisher name must be valid Kubernetes resource name"
  }
}

variable "publisher_namespace" {
  description = "Namespace where HSL publisher will be deployed"
  type        = string
}

variable "syslog_servers" {
  description = "List of syslog server addresses (host:port or just host)"
  type        = list(string)

  validation {
    condition     = length(var.syslog_servers) > 0
    error_message = "At least one syslog server must be specified"
  }
}

# =============================================================================
# OPTIONAL VARIABLES
# =============================================================================

variable "protocol" {
  description = "Protocol for syslog communication (tcp or udp)"
  type        = string
  default     = "tcp"

  validation {
    condition     = contains(["tcp", "udp"], var.protocol)
    error_message = "Protocol must be tcp or udp"
  }
}

variable "port" {
  description = "Default syslog port (used if not specified in server address)"
  type        = number
  default     = 514

  validation {
    condition     = var.port >= 1 && var.port <= 65535
    error_message = "Port must be between 1 and 65535"
  }
}

variable "pool_name" {
  description = "Server pool name for load balancing across multiple syslog servers"
  type        = string
  default     = null
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
  description = "Annotations to add to the HSL publisher resource"
  type        = map(string)
  default     = {}
}

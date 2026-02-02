# infrastructure-modules/bnk/f5bigfwpolicy/variables.tf
# F5BigFwPolicy Module Variables - Advanced Firewall Policies

# =============================================================================
# REQUIRED VARIABLES
# =============================================================================

variable "cluster_name" {
  description = "Name of the Kubernetes cluster (used for resource naming and identification)"
  type        = string
}

variable "policy_name" {
  description = "Name of the F5BigFwPolicy resource"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.policy_name))
    error_message = "Policy name must be valid Kubernetes resource name"
  }
}

variable "policy_namespace" {
  description = "Namespace where firewall policy will be deployed"
  type        = string
}

variable "default_action" {
  description = "Default action for unmatched traffic (accept, drop, reject)"
  type        = string

  validation {
    condition     = contains(["accept", "drop", "reject"], var.default_action)
    error_message = "Default action must be accept, drop, or reject"
  }
}

# =============================================================================
# FIREWALL RULES
# =============================================================================

variable "ingress_rules" {
  description = "List of ingress firewall rules"
  type = list(object({
    name              = string
    action            = string # accept, drop, reject
    protocol          = optional(string) # tcp, udp, icmp, any
    source_addresses  = optional(list(string))
    source_ports      = optional(list(string))
    dest_addresses    = optional(list(string))
    dest_ports        = optional(list(string))
    address_list_refs = optional(list(string))
    port_list_refs    = optional(list(string))
    log               = optional(bool, true)
  }))
  default = []

  validation {
    condition = alltrue([
      for rule in var.ingress_rules :
      contains(["accept", "drop", "reject"], rule.action)
    ])
    error_message = "Rule action must be accept, drop, or reject"
  }
}

variable "egress_rules" {
  description = "List of egress firewall rules"
  type = list(object({
    name              = string
    action            = string # accept, drop, reject
    protocol          = optional(string) # tcp, udp, icmp, any
    source_addresses  = optional(list(string))
    source_ports      = optional(list(string))
    dest_addresses    = optional(list(string))
    dest_ports        = optional(list(string))
    address_list_refs = optional(list(string))
    port_list_refs    = optional(list(string))
    log               = optional(bool, true)
  }))
  default = []

  validation {
    condition = alltrue([
      for rule in var.egress_rules :
      contains(["accept", "drop", "reject"], rule.action)
    ])
    error_message = "Rule action must be accept, drop, or reject"
  }
}

# =============================================================================
# LOGGING AND METADATA
# =============================================================================

variable "enable_logging" {
  description = "Enable firewall event logging"
  type        = bool
  default     = true
}

variable "description" {
  description = "Description of the firewall policy"
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
  description = "Annotations to add to the firewall policy resource"
  type        = map(string)
  default     = {}
}

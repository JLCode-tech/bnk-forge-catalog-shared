# infrastructure-modules/bnk/referencegrant/variables.tf
# ReferenceGrant Module Variables - Cross-Namespace References

# =============================================================================
# REQUIRED VARIABLES
# =============================================================================

variable "cluster_name" {
  description = "Name of the Kubernetes cluster (used for resource naming and identification)"
  type        = string
}

variable "grant_name" {
  description = "Name of the ReferenceGrant resource"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.grant_name))
    error_message = "Grant name must be valid Kubernetes resource name"
  }
}

variable "grant_namespace" {
  description = "Namespace where grant will be deployed (typically the 'to' namespace containing referenced resources)"
  type        = string
}

variable "from_namespaces" {
  description = "List of namespaces that are allowed to reference resources"
  type        = list(string)

  validation {
    condition     = length(var.from_namespaces) > 0
    error_message = "At least one from namespace must be specified"
  }
}

variable "to_resources" {
  description = "List of resource types that can be referenced (e.g., Gateway, Service, HTTPRoute)"
  type        = list(string)

  validation {
    condition     = length(var.to_resources) > 0
    error_message = "At least one resource type must be specified"
  }

  validation {
    condition = alltrue([
      for resource in var.to_resources :
      contains(["Gateway", "Service", "HTTPRoute", "GRPCRoute", "TCPRoute", "TLSRoute", "UDPRoute"], resource)
    ])
    error_message = "Resource types must be valid Gateway API or Kubernetes resources"
  }
}

# =============================================================================
# OPTIONAL VARIABLES
# =============================================================================

variable "to_resource_names" {
  description = "Specific resource names that can be referenced (empty list = all resources of specified types)"
  type        = list(string)
  default     = []
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
  description = "Annotations to add to the grant resource"
  type        = map(string)
  default     = {}
}

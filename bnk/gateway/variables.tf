# infrastructure-modules/spk-2.1/gateway/variables.tf
# Gateway Module Variables - Creates Gateway API Gateway instances
# This module is cloud-agnostic - works with any Kubernetes cluster

# =============================================================================
# CLUSTER CONFIGURATION
# =============================================================================

variable "cluster_name" {
  description = "Name of the Kubernetes cluster (used for resource naming and identification)"
  type        = string
}

variable "gateway_name" {
  description = "Name of the Gateway resource"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.gateway_name))
    error_message = "Gateway name must be valid Kubernetes resource name"
  }
}

variable "gateway_namespace" {
  description = "Namespace where Gateway will be deployed"
  type        = string
}

variable "gatewayclass_name" {
  description = "Name of the BNKGatewayClass to use"
  type        = string
}

# =============================================================================
# LISTENER CONFIGURATION
# =============================================================================

variable "listeners" {
  description = "List of listeners for the Gateway"
  type = list(object({
    name     = string
    protocol = string # HTTP, HTTPS, TCP, UDP, TLS
    port     = number
    hostname = optional(string)
    tls = optional(object({
      mode = string # Terminate, Passthrough
      certificate_ref = optional(object({
        name      = string
        namespace = optional(string)
      }))
    }))
    allowed_routes = optional(object({
      namespaces = optional(object({
        from     = string # Same, All, Selector
        selector = optional(map(string))
      }))
      kinds = optional(list(object({
        group = string
        kind  = string
      })))
    }))
  }))

  validation {
    condition = alltrue([
      for listener in var.listeners :
      contains(["HTTP", "HTTPS", "TCP", "UDP", "TLS"], listener.protocol)
    ])
    error_message = "Listener protocol must be one of: HTTP, HTTPS, TCP, UDP, TLS"
  }
}

# =============================================================================
# ADDRESS CONFIGURATION
# =============================================================================

variable "addresses" {
  description = "Addresses for the Gateway (optional, managed by IPAM if not specified)"
  type = list(object({
    type  = string # IPAddress, Hostname
    value = string
  }))
  default = []
}

# =============================================================================
# TMM CONFIGURATION OVERRIDES
# =============================================================================

variable "tmm_replicas" {
  description = "Number of TMM replicas (overrides GatewayClass default)"
  type        = number
  default     = null

  validation {
    condition     = var.tmm_replicas == null || (var.tmm_replicas >= 1 && var.tmm_replicas <= 10)
    error_message = "TMM replicas must be between 1 and 10 if specified"
  }
}

variable "tmm_resources" {
  description = "TMM resource requirements (overrides GatewayClass defaults)"
  type = object({
    cpu           = optional(string)
    memory        = optional(string)
    hugepages_2mi = optional(string)
  })
  default = null
}

# =============================================================================
# NETWORK CONFIGURATION
# =============================================================================

variable "network_attachments" {
  description = "Network attachment overrides for TMM pods. Accepts either an object {external, internal} or a list [external, internal] (from cneinstance output)."
  type        = any
  default     = null
}

# =============================================================================
# SERVICE CONFIGURATION
# =============================================================================

variable "service_type" {
  description = "Kubernetes service type (overrides GatewayClass default)"
  type        = string
  default     = null

  validation {
    condition     = var.service_type == null || contains(["LoadBalancer", "ClusterIP", "NodePort"], var.service_type)
    error_message = "Service type must be LoadBalancer, ClusterIP, or NodePort"
  }
}

variable "service_annotations" {
  description = "Annotations to add to the Gateway service"
  type        = map(string)
  default     = {}
}

# =============================================================================
# IPAM CONFIGURATION
# =============================================================================

variable "enable_ipam" {
  description = "Enable IPAM for automatic IP allocation"
  type        = bool
  default     = true
}

variable "ipam_selector" {
  description = "IPAM pool selector labels"
  type        = map(string)
  default     = {}
}

variable "infrastructure_parameters_ref" {
  description = "Reference to F5BnkGateway for IPAM integration"
  type = object({
    group = optional(string, "k8s.f5net.com")
    kind  = optional(string, "F5BnkGateway")
    name  = string
  })
  default = null
}

variable "gateway_addresses" {
  description = "Static IP addresses for Gateway (optional, used with IPAM)"
  type = list(object({
    type  = optional(string, "IPAddress")
    value = string
  }))
  default = []
}

# =============================================================================
# POLICY ATTACHMENTS
# =============================================================================

variable "security_policy_refs" {
  description = "List of security extension references (F5BigFwPolicy, F5BigDdosGlobal, etc.) to attach via BNKSecPolicy"
  type = list(object({
    name      = string
    kind      = optional(string) # e.g., F5BigFwPolicy, F5BigDdosGlobal, F5BigLogProfile
    namespace = optional(string)
  }))
  default = []
}

variable "network_policy_refs" {
  description = "List of network extension references (F5BigCneIrule, etc.) to attach via BNKNetPolicy"
  type = list(object({
    name      = string
    kind      = optional(string) # e.g., F5BigCneIrule
    namespace = optional(string)
  }))
  default = []
}

# =============================================================================
# DEPENDENCY INPUTS
# =============================================================================

variable "gatewayclass_ready" {
  description = "Dependency flag indicating GatewayClass is ready"
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
  description = "Annotations to add to the Gateway resource"
  type        = map(string)
  default     = {}
}

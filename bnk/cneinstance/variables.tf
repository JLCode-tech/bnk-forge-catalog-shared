# infrastructure-modules/bnk/cneinstance/variables.tf
# CNEInstance Module Variables - BNK GA 2.2
# This module creates a CNEInstance custom resource for BIG-IP Next for Kubernetes

# =============================================================================
# REQUIRED VARIABLES
# =============================================================================

variable "cluster_name" {
  description = "Name of the Kubernetes cluster (used for EKS authentication)"
  type        = string
}

variable "instance_name" {
  description = "Name of the CNEInstance resource"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.instance_name))
    error_message = "Instance name must be valid Kubernetes resource name (lowercase, alphanumeric, hyphens)"
  }
}

variable "instance_namespace" {
  description = "Namespace where CNEInstance will be deployed"
  type        = string
}

variable "manifest_version" {
  description = "The CNEInstance/BNK version to be installed (e.g., '2.2.0')"
  type        = string
}

variable "registry_uri" {
  description = "Container registry URI for BNK images (e.g., 'myregistry.example.com/f5-bnk')"
  type        = string
  default     = "repo.f5.com"
}

variable "external_nad_name" {
  description = "Name of the external network attachment definition (from network-setup module)"
  type        = string
}

variable "internal_nad_name" {
  description = "Name of the internal network attachment definition (from network-setup module)"
  type        = string
}

# =============================================================================
# OPTIONAL VARIABLES - Product Configuration
# =============================================================================

variable "product_type" {
  description = "Product type: 'BNK' for BIG-IP Next for Kubernetes or 'CNF' for Cloud Native Functions"
  type        = string
  default     = "BNK"

  validation {
    condition     = contains(["BNK", "CNF"], var.product_type)
    error_message = "Product type must be 'BNK' or 'CNF'"
  }
}

variable "gateway_api_enabled" {
  description = "Enable Gateway API support for this CNEInstance"
  type        = bool
  default     = true
}

# =============================================================================
# OPTIONAL VARIABLES - Deployment Configuration
# =============================================================================

variable "deployment_size" {
  description = "Deployment size determines resource allocation: Small, Medium, Large, or Max"
  type        = string
  default     = "Small"

  validation {
    condition     = contains(["Small", "Medium", "Large", "Max"], var.deployment_size)
    error_message = "Deployment size must be one of: Small, Medium, Large, Max"
  }
}

# =============================================================================
# OPTIONAL VARIABLES - Certificate Configuration
# =============================================================================

variable "cluster_issuer_name" {
  description = "Name of the cert-manager ClusterIssuer (from cert-manager module)"
  type        = string
  default     = ""
}

# =============================================================================
# OPTIONAL VARIABLES - Registry Configuration
# =============================================================================

variable "image_pull_policy" {
  description = "Image pull policy: Always, IfNotPresent, or Never"
  type        = string
  default     = "IfNotPresent"

  validation {
    condition     = contains(["Always", "IfNotPresent", "Never"], var.image_pull_policy)
    error_message = "Image pull policy must be one of: Always, IfNotPresent, Never"
  }
}

variable "far_secret_name" {
  description = "Name of the FAR pull secret (from far-setup module)"
  type        = string
  default     = "far-secret"
}

# =============================================================================
# OPTIONAL VARIABLES - Advanced Configuration
# =============================================================================

variable "demo_mode" {
  description = "Enable demo mode (disables hugepages requirement, uses generalized drivers)"
  type        = bool
  default     = false
}

variable "advanced_config" {
  description = "Advanced configuration options (optional)"
  type = object({
    maintenance_mode = optional(bool, false)
    env_discovery = optional(object({
      enabled = optional(bool, false)
    }), {})
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
  description = "Annotations to add to the CNEInstance resource"
  type        = map(string)
  default     = {}
}

# bnk/cneinstance/variables.tf
# CNEInstance Module Variables

# =============================================================================
# CLUSTER / INSTANCE
# =============================================================================

variable "cluster_name" {
  description = "Name of the Kubernetes cluster (auto-wired)"
  type        = string
  default     = ""
}

variable "instance_name" {
  description = "Name of the CNEInstance resource"
  type        = string
  default     = "bnk-instance"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.instance_name))
    error_message = "Instance name must be a valid Kubernetes resource name"
  }
}

variable "instance_namespace" {
  description = "Namespace for CNEInstance (wired from flo.flo_namespace)"
  type        = string
  default     = "f5-operator"
}

# =============================================================================
# VERSION AND REGISTRY (wired from prerequisites)
# =============================================================================

variable "manifest_version" {
  description = "BNK manifest version (wired from prerequisites.manifest_version)"
  type        = string
  default     = "2.2.0-3.2226.0-0.0.385"
}

variable "far_secret_name" {
  description = "FAR image pull secret name (wired from prerequisites.far_secret_name)"
  type        = string
  default     = "far-secret"
}

# =============================================================================
# NETWORK (wired from network-setup)
# =============================================================================

variable "external_nad_name" {
  description = "External NAD name (wired from network-setup.external_nad_name)"
  type        = string
  default     = "external-netdevice"
}

variable "internal_nad_name" {
  description = "Internal NAD name (wired from network-setup.internal_nad_name)"
  type        = string
  default     = "internal-netdevice"
}

# =============================================================================
# CERTIFICATES (wired from cert-manager)
# =============================================================================

variable "cluster_issuer_name" {
  description = "ClusterIssuer name (wired from cert-manager.cluster_issuer_name)"
  type        = string
  default     = "bnk-ca-cluster-issuer"
}

# =============================================================================
# DEPLOYMENT CONFIGURATION
# =============================================================================

variable "deployment_size" {
  description = "Deployment size: Small, Medium, Large, or Max"
  type        = string
  default     = "Small"

  validation {
    condition     = contains(["Small", "Medium", "Large", "Max"], var.deployment_size)
    error_message = "Deployment size must be one of: Small, Medium, Large, Max"
  }
}

# =============================================================================
# DEPENDENCY GATES
# =============================================================================

variable "flo_ready" {
  description = "Gate from FLO module — ensures FLO is deployed and CRDs exist"
  type        = bool
  default     = true
}

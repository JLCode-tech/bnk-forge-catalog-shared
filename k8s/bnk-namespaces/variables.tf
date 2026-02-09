# k8s/bnk-namespaces/variables.tf
# BNK Namespaces Module Variables
#
# Default values align with F5 BNK 2.2 CloudDocs recommendations

# =============================================================================
# NAMESPACE CONFIGURATION
# =============================================================================

variable "bnk_namespace" {
  description = "Namespace for core BNK components (FLO, CWC, TMM). Per F5 docs, 'f5-bnk' is standard."
  type        = string
  default     = "f5-bnk"
}

variable "utils_namespace" {
  description = "Namespace for BNK utility components (IPAM, observability). Per F5 docs, 'f5-utils' is standard."
  type        = string
  default     = "f5-utils"
}

variable "gateway_namespace" {
  description = "Namespace for Gateway API resources (Gateway, HTTPRoute, policies). User-defined."
  type        = string
  default     = "gateway-ns"
}

variable "create_gateway_namespace" {
  description = "Whether to create the gateway namespace. Set to false if it already exists."
  type        = bool
  default     = true
}

# =============================================================================
# FAR IMAGE PULL SECRET CONFIGURATION
# =============================================================================

variable "create_far_secrets" {
  description = "Whether to create FAR image pull secrets in namespaces. Requires far_docker_config."
  type        = bool
  default     = false
}

variable "far_secret_name" {
  description = "Name of the FAR image pull secret"
  type        = string
  default     = "f5-far-secret"
}

variable "far_docker_config" {
  description = "Docker config JSON for FAR authentication (base64 encoded). Leave empty to skip secret creation."
  type        = string
  default     = ""
  sensitive   = true
}

# =============================================================================
# CLUSTER IDENTIFICATION
# =============================================================================

variable "cluster_name" {
  description = "Name of the Kubernetes cluster (for resource tagging and identification)"
  type        = string
  default     = ""
}

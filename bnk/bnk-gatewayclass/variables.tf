# bnk-forge-modules/bnk/bnk-gatewayclass/variables.tf
# GatewayClass Module Variables (BNK 2.2 GA)

# =============================================================================
# CLUSTER CONFIGURATION
# =============================================================================

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
}

variable "gatewayclass_name" {
  description = "Name of the GatewayClass resource"
  type        = string
  default     = "bnk-gatewayclass"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.gatewayclass_name))
    error_message = "GatewayClass name must be a valid Kubernetes resource name"
  }
}

variable "flo_namespace" {
  description = "Namespace where FLO is deployed (used to construct controllerName)"
  type        = string
}

# =============================================================================
# CONTROLLER CONFIGURATION
# =============================================================================

variable "controller_name" {
  description = "Controller name for GatewayClass. Per F5 docs: f5.com/<namespace>-f5-cne-controller"
  type        = string
  default     = ""
}

variable "description" {
  description = "Description of the GatewayClass"
  type        = string
  default     = "F5 BIG-IP Kubernetes Gateway"
}

# =============================================================================
# DEPENDENCY INPUTS
# =============================================================================

variable "flo_ready" {
  description = "Dependency flag indicating FLO is ready and CRDs are installed"
  type        = bool
}

# =============================================================================
# LABELS
# =============================================================================

variable "common_labels" {
  description = "Common labels to apply to all Kubernetes resources"
  type        = map(string)
  default     = {}
}

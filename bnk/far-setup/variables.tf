# bnk/far-setup/variables.tf
# F5 BIG-IP Next for Kubernetes (BNK) 2.2 - FAR Setup Variables

# =============================================================================
# REQUIRED VARIABLES
# =============================================================================

variable "bnk_manifest_version" {
  description = "BNK manifest version to download from FAR (e.g., 2.2.0-3.2226.0-0.0.385)"
  type        = string
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+-[0-9]+\\.[0-9]+\\.[0-9]+-[0-9]+\\.[0-9]+\\.[0-9]+$", var.bnk_manifest_version))
    error_message = "BNK manifest version must follow format: X.Y.Z-A.B.C-D.E.F (e.g., 2.2.0-3.2226.0-0.0.385)"
  }
}

# Backward compatibility alias
variable "spk_manifest_version" {
  description = "DEPRECATED: Use bnk_manifest_version instead. Kept for backward compatibility."
  type        = string
  default     = ""
}

variable "manifest_chart_name" {
  description = "Name of the F5 manifest chart in FAR"
  type        = string
  default     = "f5-bigip-k8s-manifest"
}

variable "service_account_key_file" {
  description = "Path to F5 FAR service account key JSON file"
  type        = string
  validation {
    condition     = can(file(var.service_account_key_file))
    error_message = "Service account key file must exist and be readable"
  }
}

variable "bnk_namespace" {
  description = "Kubernetes namespace for BNK controller and TMM components"
  type        = string
  default     = "f5-bnk"
  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.bnk_namespace))
    error_message = "Namespace must be valid Kubernetes namespace name (lowercase alphanumeric and hyphens)"
  }
}

# Backward compatibility alias
variable "spk_namespace" {
  description = "DEPRECATED: Use bnk_namespace instead. Kept for backward compatibility."
  type        = string
  default     = ""
}

variable "operator_namespace" {
  description = "Kubernetes namespace for FLO and all BNK components deployed via CNEInstance"
  type        = string
  default     = "f5-operator"
  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.operator_namespace))
    error_message = "Namespace must be valid Kubernetes namespace name (lowercase alphanumeric and hyphens)"
  }
}

variable "utils_namespace" {
  description = "Kubernetes namespace for shared F5 utility components"
  type        = string
  default     = "f5-utils"
  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.utils_namespace))
    error_message = "Namespace must be valid Kubernetes namespace name (lowercase alphanumeric and hyphens)"
  }
}

# =============================================================================
# OPTIONAL VARIABLES
# =============================================================================

variable "create_namespaces" {
  description = "Whether to create the BNK and utils namespaces (set false if using bnk-namespaces module)"
  type        = bool
  default     = false
}

# =============================================================================
# TAGS AND LABELS
# =============================================================================

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "common_labels" {
  description = "Common labels to apply to all Kubernetes resources"
  type        = map(string)
  default     = {}
}

# =============================================================================
# CLUSTER CONFIGURATION
# =============================================================================

variable "cluster_name" {
  description = "Name of the Kubernetes cluster (used for resource naming and identification)"
  type        = string
  default     = ""
}

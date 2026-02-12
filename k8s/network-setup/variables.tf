# k8s/network-setup/variables.tf
# Network Setup Module Variables

# =============================================================================
# CLUSTER / NAMESPACE
# =============================================================================

variable "cluster_name" {
  description = "Name of the Kubernetes cluster (auto-wired)"
  type        = string
  default     = ""
}

variable "namespace" {
  description = "Namespace for NADs — must match CNEInstance namespace (f5-operator)"
  type        = string
  default     = "f5-operator"
}

# =============================================================================
# CNI CONFIGURATION (no hardcoded PCI bus IDs!)
# =============================================================================

variable "cni_type" {
  description = "CNI plugin type for NADs (host-device for AWS SR-IOV, sf for DPU, sriov, vfio)"
  type        = string
  default     = "host-device"
}

variable "external_resource_name" {
  description = "SR-IOV device plugin resource name for external network"
  type        = string
  default     = "intel.com/external_netdevice"
}

variable "internal_resource_name" {
  description = "SR-IOV device plugin resource name for internal network"
  type        = string
  default     = "intel.com/internal_netdevice"
}

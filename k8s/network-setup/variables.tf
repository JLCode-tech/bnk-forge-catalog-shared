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
# SUBNET CIDRS (wired from VPC or user-configured)
# =============================================================================

variable "external_subnet_cidrs" {
  description = "List of external subnet CIDRs for IPAM ranges (one per AZ)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "internal_subnet_cidrs" {
  description = "List of internal subnet CIDRs for IPAM ranges (one per AZ)"
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24"]
}

# =============================================================================
# CNI CONFIGURATION (no hardcoded PCI bus IDs!)
# =============================================================================

variable "cni_type" {
  description = "CNI plugin type for NADs (host-device, sriov, vfio)"
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

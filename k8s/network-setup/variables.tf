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
# SELF IPS — deterministic IPs for TMM (one per AZ, matching subnet_cidrs order)
# These are used as IPAM rangeStart=rangeEnd so Multus always assigns this
# exact IP. The VLAN module must use the same IPs for selfip_v4s.
# =============================================================================

variable "external_self_ips" {
  description = "Fixed external self IPs for TMM (one per AZ). Must be within the corresponding external_subnet_cidrs."
  type        = list(string)
  default     = ["10.0.10.240", "10.0.11.240"]
}

variable "internal_self_ips" {
  description = "Fixed internal self IPs for TMM (one per AZ). Must be within the corresponding internal_subnet_cidrs."
  type        = list(string)
  default     = ["10.0.20.240", "10.0.21.240"]
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

# bnk/bnk-vlans/variables.tf
# F5SPKVlan Module Variables

# =============================================================================
# CLUSTER
# =============================================================================

variable "cluster_name" {
  description = "Name of the Kubernetes cluster (auto-wired)"
  type        = string
  default     = ""
}

variable "namespace" {
  description = "Namespace for VLAN CRs (must match CNEInstance namespace)"
  type        = string
  default     = "f5-operator"
}

# =============================================================================
# SELF IPS — must match NAD IPAM rangeStart/rangeEnd from network-setup
# =============================================================================

variable "external_self_ips" {
  description = "External self IPs for TMM VLANs (one per AZ, wired from network-setup.external_self_ips)"
  type        = list(string)
  default     = ["10.0.10.240", "10.0.11.240"]
}

variable "internal_self_ips" {
  description = "Internal self IPs for TMM VLANs (one per AZ, wired from network-setup.internal_self_ips)"
  type        = list(string)
  default     = ["10.0.20.240", "10.0.21.240"]
}

# =============================================================================
# SUBNET CIDRS — needed to derive prefix length
# =============================================================================

variable "external_subnet_cidrs" {
  description = "External subnet CIDRs (wired from network-setup.external_subnet_cidrs)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "internal_subnet_cidrs" {
  description = "Internal subnet CIDRs (wired from network-setup.internal_subnet_cidrs)"
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24"]
}

# =============================================================================
# MTU
# =============================================================================

variable "mtu" {
  description = "MTU for VLAN interfaces (should match TMM_DEFAULT_MTU)"
  type        = number
  default     = 9000
}

# =============================================================================
# DEPENDENCY GATES
# =============================================================================

variable "cneinstance_ready" {
  description = "Gate from CNEInstance module — ensures FLO has deployed CRDs and TMM"
  type        = bool
  default     = true
}

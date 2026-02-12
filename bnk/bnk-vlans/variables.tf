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
# SELF IPS — static IPs that TMM will configure on its data-plane interfaces
# These are chosen by the operator from the subnet range.
# One IP per TMM replica. NADs have NO IPAM — TMM sets these IPs itself
# via the F5SPKVlan CR.
# =============================================================================

variable "external_self_ips" {
  description = "External self IPs for TMM VLANs (one per TMM replica, from external subnet)"
  type        = list(string)
  default     = ["10.0.10.240"]
}

variable "internal_self_ips" {
  description = "Internal self IPs for TMM VLANs (one per TMM replica, from internal subnet)"
  type        = list(string)
  default     = ["10.0.20.240"]
}

# =============================================================================
# SUBNET CIDRS — needed to derive prefix length
# =============================================================================

variable "external_subnet_cidrs" {
  description = "External subnet CIDRs (used to derive prefix length for VLAN CR)"
  type        = list(string)
  default     = ["10.0.10.0/24"]
}

variable "internal_subnet_cidrs" {
  description = "Internal subnet CIDRs (used to derive prefix length for VLAN CR)"
  type        = list(string)
  default     = ["10.0.20.0/24"]
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

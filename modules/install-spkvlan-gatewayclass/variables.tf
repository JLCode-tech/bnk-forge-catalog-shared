# =============================================================================
# Forge-injected kubeconfig
# =============================================================================

variable "forge_kubeconfig_content" {
  description = "Plain-text kubeconfig used for kubectl applies. Forge overrides this at deploy time with a local.forge_kubeconfig reference. Sensitive."
  type        = string
  sensitive   = true
  default     = ""
}

# =============================================================================
# Cluster identity
# =============================================================================

variable "cluster_name" {
  description = "Logical name of the BNK cluster (e.g. 'my-eks-cluster'). Used to name the GatewayClass CR: <cluster_name>-gatewayclass. Matches awsbnkctl cl.Metadata.Name."
  type        = string
}

# =============================================================================
# CNE namespace
# =============================================================================

variable "instance_namespace" {
  description = "Kubernetes namespace where the CNEInstance and F5SPKVlan CRs are applied. Must match the namespace used by cneinstall. Default matches awsbnkctl bnkconst.InstanceNamespace = 'f5-cne-system'."
  type        = string
  default     = "f5-cne-system"
}

# =============================================================================
# Data-plane SelfIP configuration
# =============================================================================
# These values are cloud-specific: on AWS they are secondary IPs assigned to
# the external (and internal) ENIs in Phase 17. The per-cloud catalog module
# (eks-cluster-install-spkvlan-gatewayclass) sources them from the
# eks-cluster-register outputs (tmm_external_subnets_by_az) or from the
# secondary-ENI attach phase's outputs. They must NOT be hardcoded here.
#
# Source for how awsbnkctl derives them:
#   awsbnkctl:internal/aws/phases/phase23b_spkvlan_gatewayclass.go
#   awsbnkctl:internal/k8s/render/render.go F5SPKVlanVars

variable "tmm_ext_selfip" {
  description = "SelfIP address for the external TMM VLAN (trunk 1.1, ext-vlan). On AWS: a secondary private IP on the external ENI, derived from the external data-plane subnet CIDR (e.g. '10.0.10.240'). Matches awsbnkctl cl.Network.DataPath.SelfIPs.External."
  type        = string
}

variable "tmm_int_selfip" {
  description = "SelfIP address for the internal TMM VLAN (trunk 1.2, int-vlan). Required when has_internal_interface=true. On AWS: a secondary private IP on the internal ENI. Matches awsbnkctl cl.Network.DataPath.SelfIPs.Internal. Ignored (may be empty) when has_internal_interface=false."
  type        = string
  default     = ""
}

variable "tmm_selfip_prefixlen" {
  description = "IPv4 prefix length for both SelfIPs (e.g. 24 for a /24 subnet). Must match the data-plane subnet prefix length. Matches awsbnkctl cl.Network.DataPath.SelfIPs.PrefixLen."
  type        = number
  default     = 24
}

variable "has_internal_interface" {
  description = "When true, apply the int-vlan F5SPKVlan CR in addition to ext-vlan. Set true for dual-interface TMM patterns (external + internal data planes). Set false for single-interface (external-only) patterns. Matches awsbnkctl cl.HasInternalInterface()."
  type        = bool
  default     = false
}

# =============================================================================
# GatewayClass name
# =============================================================================

variable "gatewayclass_name" {
  description = "Name of the GatewayClass CR. Empty = auto-derive as '<cluster_name>-gatewayclass' (awsbnkctl default). Override only if your operator-facing Gateway CRs reference a specific class name."
  type        = string
  default     = ""
}

# =============================================================================
# Timing
# =============================================================================

variable "crd_wait_timeout" {
  description = "Timeout (kubectl wait format) for each CRD to be Established. FLO installs the F5SPKVlan + GatewayClass CRDs only after CNEInstance reconciles, which can take 10+ minutes on a cold cluster. Default 600s (10 min) is generous. Matches awsbnkctl phase23b f5spkvlanCRDWait=3min (per warm cluster); increase for cold clusters."
  type        = string
  default     = "600s"
}

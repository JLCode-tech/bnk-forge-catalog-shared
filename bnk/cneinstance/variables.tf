# bnk/cneinstance/variables.tf
# CNEInstance Module Variables

# =============================================================================
# PLATFORM KUBECONFIG (injected by BNK-Forge or set manually)
# =============================================================================

variable "forge_kubeconfig_content" {
  description = "Kubeconfig YAML content. Automatically injected by BNK-Forge for any platform (EKS, AKS, GKE, OCP, generic). Set manually for standalone usage."
  type        = string
  default     = ""
  sensitive   = true
}

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
  default     = "2.2.1-3.2226.0-0.0.511"
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
# CLOUD CONFIGURATION (AWS/Azure)
# =============================================================================

variable "cloud_provider" {
  description = "Cloud provider (aws, azure, or empty for generic/on-prem). Enables cloud-aware controller env vars."
  type        = string
  default     = ""

  validation {
    condition     = contains(["", "aws", "azure"], var.cloud_provider)
    error_message = "cloud_provider must be one of: '' (empty), 'aws', 'azure'"
  }
}

variable "storage_class_name" {
  description = "StorageClass for DSSM PVCs (e.g. gp3 for AWS EBS CSI driver). Empty uses cluster default."
  type        = string
  default     = ""
}

variable "cloud_az_subnet_mappings" {
  description = "AZ-to-subnet mappings for cloud-network-mapping ConfigMap. Required when cloud_provider is set."
  type = list(object({
    az = string
    subnets = list(object({
      cidr      = string
      subnet_id = string
    }))
  }))
  default = []
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

variable "whole_cluster" {
  description = "Watch all namespaces for Gateway/Route CRs. With dpu=false, creates a Deployment."
  type        = bool
  default     = true
}

variable "dpu_enabled" {
  description = "Enable DPU (BlueField) mode. Must be explicitly false for AWS/standard k8s."
  type        = bool
  default     = false
}

# =============================================================================
# FEATURE TOGGLES
# These MUST be explicitly set. Empty {} in CRD causes FLO to generate a
# minimal TMM template missing volume mounts and sidecars.
# =============================================================================

variable "dynamic_routing_enabled" {
  description = "Enable dynamic routing (adds tmrouted container to TMM pod)"
  type        = bool
  default     = true
}

variable "firewall_acl_enabled" {
  description = "Enable firewall ACL (adds blobd sidecar + AFM deployment)"
  type        = bool
  default     = true
}

variable "pseudo_cni_enabled" {
  description = "Enable pseudoCNI / CSRC DaemonSet"
  type        = bool
  default     = true
}

variable "core_collection_enabled" {
  description = "Enable core dump collection (DaemonSet per node, uses CPU/PV resources)"
  type        = bool
  default     = false
}

variable "intelligent_lb_enabled" {
  description = "Enable AI Intelligent Load Balancing (deploys f5-analyzer pod for F5BigAnalyzer CRs)"
  type        = bool
  default     = false
}

variable "telemetry_logging_enabled" {
  description = "Enable logging subsystem (fluentbit sidecars)"
  type        = bool
  default     = true
}

variable "telemetry_metrics_enabled" {
  description = "Enable metrics subsystem (observer, OTEL collector, toda-tmstats)"
  type        = bool
  default     = true
}

# =============================================================================
# ENV DISCOVERY
# Disabled by default: checks for OVN annotations (k8s.ovn.org/node-primary-ifaddr)
# which don't exist on AWS VPC CNI, causing false failures on all nodes.
# =============================================================================

variable "env_discovery_enabled" {
  description = "Enable environment discovery (validates SR-IOV, hugepages, node labels)"
  type        = bool
  default     = false
}

variable "env_discovery_stop_on_fail" {
  description = "Halt deployment if envDiscovery finds issues"
  type        = bool
  default     = false
}

# =============================================================================
# TMM ENVIRONMENT VARIABLES
# =============================================================================

variable "tmm_default_mtu" {
  description = "MTU for TMM interfaces (should match your network, e.g. 9000 for jumbo frames)"
  type        = number
  default     = 9000
}

variable "tmm_ignore_gateways" {
  description = "Prevent TMM from using eth0 default gateway (required for SR-IOV setups)"
  type        = bool
  default     = true
}

variable "tmm_extra_env" {
  description = "Additional environment variables for TMM container"
  type        = list(object({ name = string, value = string }))
  default     = []
}

variable "controller_extra_env" {
  description = "Additional environment variables for CNE controller"
  type        = list(object({ name = string, value = string }))
  default     = []
}

# =============================================================================
# DEPENDENCY GATES
# =============================================================================

variable "flo_ready" {
  description = "Gate from FLO module — ensures FLO is deployed and CRDs exist"
  type        = bool
  default     = true
}

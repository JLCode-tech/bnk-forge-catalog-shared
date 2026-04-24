# infra/aws/cne-irsa/variables.tf
# IRSA + IAM policy for the F5 CNE controller's ServiceAccount, so it can
# call ec2:AssignPrivateIpAddresses to attach BNK Gateway VIPs and F5SPKVlan
# selfips as secondary IPs on the dedicated SR-IOV / host-device ENIs.
#
# Per F5 Doc 3 (AWS Cloud Multi-AZ Network Architecture Deployment Guide,
# pages 28-31). Required when bnk/cneinstance.tmm_data_plane_mode = "kernel".

# =============================================================================
# CLUSTER (wired from infra/aws/eks)
# =============================================================================

variable "cluster_name" {
  description = "EKS cluster name (wired from infra/aws/eks.cluster_name)"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the cluster's IAM OIDC provider (wired from infra/aws/eks.oidc_provider_arn)"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of the cluster's IAM OIDC provider (wired from infra/aws/eks.oidc_provider_url) — without https:// prefix is fine; the module strips it"
  type        = string
}

# =============================================================================
# CNE CONTROLLER ServiceAccount (created by FLO when CNEInstance CR is applied)
# =============================================================================

variable "cne_controller_namespace" {
  description = "Namespace where the CNE controller runs (wired from bnk/cneinstance.instance_namespace)"
  type        = string
  default     = "f5-operator"
}

variable "cne_controller_sa_name" {
  description = "ServiceAccount name of the CNE controller. FLO names this from the CNEInstance: f5-cne-controller-<instance_name>-f5-cne-controller-serviceaccount."
  type        = string
  default     = "f5-cne-controller-default-f5-cne-controller-serviceaccount"
}

variable "cne_controller_deployment_name" {
  description = "Deployment name of the CNE controller (used to rollout-restart so IRSA env vars are injected into a fresh pod after the SA is annotated)"
  type        = string
  default     = "f5-cne-controller"
}

# =============================================================================
# IAM (role + policy)
# =============================================================================

variable "role_name" {
  description = "Name of the IAM role bound to the CNE controller SA via IRSA. Defaults to <cluster_name>-cne-controller-vip; override if your AWS account has length/uniqueness constraints."
  type        = string
  default     = ""
}

variable "policy_name" {
  description = "Name of the IAM policy attached to the IRSA role. Per Doc 3 the policy is called allow-ec2-vip; defaults to <cluster_name>-allow-ec2-vip to keep it cluster-scoped."
  type        = string
  default     = ""
}

variable "extra_managed_policy_arns" {
  description = "Optional additional managed policy ARNs to attach to the role (e.g. arn:aws:iam::aws:policy/ReadOnlyAccess)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to all IAM resources"
  type        = map(string)
  default     = {}
}

# =============================================================================
# KUBECONFIG (Forge-injected) for the SA annotation step
# =============================================================================

variable "forge_kubeconfig_content" {
  description = "Kubeconfig YAML content. Auto-injected by BNK-Forge for any platform; set manually for standalone use."
  type        = string
  default     = ""
  sensitive   = true
}

# =============================================================================
# DEPENDENCY GATE
# =============================================================================
# The SA only exists once FLO has reconciled the CNEInstance CR. Pass the
# cneinstance module's `instance_ready` output here so this module's
# annotate-SA step doesn't run before the SA exists.

variable "cneinstance_ready" {
  description = "Gate from bnk/cneinstance — ensures FLO has created the CNE controller SA before we try to annotate it"
  type        = bool
  default     = true
}

variable "wait_for_sa_timeout_seconds" {
  description = "How long to wait for the SA to appear before the annotate-and-restart step gives up. FLO is usually fast (<60s) but can be slow on first deploy."
  type        = number
  default     = 300
}

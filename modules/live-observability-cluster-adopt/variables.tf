# =============================================================================
# live-observability-cluster-adopt
# =============================================================================
# Accepts a plain-text kubeconfig for any Kubernetes cluster and validates
# connectivity. The kubeconfig is written to disk (mode 0600) and verified
# via `kubectl cluster-info --request-timeout=10s` before downstream modules
# are allowed to proceed.
#
# NOTE: This module does NOT auto-register the cluster in Forge. Forge
# auto-registration (the cluster DB row that PR #393 dashboard queries) requires
# either an SSH-fetched kubeconfig (remote_kubeconfig_path contract) or a
# cloud-provider-specific register module (eks-cluster-register, etc.). For an
# imported blueprint with a direct kubeconfig, register the cluster manually via
# Forge UI (Settings > Clusters > Add cluster) after the blueprint deploys.

variable "cluster_name" {
  description = "Human-readable name for the target cluster. Used as a label in module outputs and Forge project context. Register this same name in Forge Clusters to enable the PR #393 Loki dashboard."
  type        = string
}

variable "kubeconfig_content" {
  description = "Full plain-text kubeconfig for the target cluster. Sensitive — never logged or emitted in plaintext outputs. Supports any Kubernetes cluster (EKS, AKS, GKE, ROKS, on-prem). Forge passes this value to all downstream modules as forge_kubeconfig_content."
  type        = string
  sensitive   = true
}

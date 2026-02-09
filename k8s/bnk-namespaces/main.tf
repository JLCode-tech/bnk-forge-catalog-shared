# k8s/bnk-namespaces/main.tf
# BNK Namespaces Module for F5 BIG-IP Next for Kubernetes
#
# Creates the required namespaces for BNK deployment:
# - f5-bnk: Core BNK components (FLO, CWC, TMM)
# - f5-utils: Utility components (IPAM, observability)
# - Gateway namespace: User-defined namespace for Gateway resources
#
# Reference: https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/

# =============================================================================
# BNK CORE NAMESPACE (f5-bnk)
# =============================================================================
# This namespace hosts the core BNK components:
# - F5 Lifecycle Operator (FLO)
# - Cluster-Wide Controller (CWC)
# - TMM pods (Traffic Management Microkernel)

resource "kubernetes_namespace_v1" "f5_bnk" {
  metadata {
    name = var.bnk_namespace

    labels = {
      "app.kubernetes.io/name"       = "f5-bnk"
      "app.kubernetes.io/component"  = "bnk-system"
      "app.kubernetes.io/managed-by" = "terraform"
      "f5.com/product"               = "bnk"
    }

    annotations = {
      "description" = "F5 BIG-IP Next for Kubernetes core components"
    }
  }
}

# =============================================================================
# UTILITIES NAMESPACE (f5-utils)
# =============================================================================
# This namespace hosts utility components:
# - F5 IPAM Controller
# - Observability components (OTEL collector, Fluentd)
# - dSSM database

resource "kubernetes_namespace_v1" "f5_utils" {
  metadata {
    name = var.utils_namespace

    labels = {
      "app.kubernetes.io/name"       = "f5-utils"
      "app.kubernetes.io/component"  = "bnk-utilities"
      "app.kubernetes.io/managed-by" = "terraform"
      "f5.com/product"               = "bnk"
    }

    annotations = {
      "description" = "F5 BIG-IP Next for Kubernetes utility components"
    }
  }
}

# =============================================================================
# GATEWAY NAMESPACE
# =============================================================================
# This namespace hosts the Gateway API resources:
# - Gateway
# - HTTPRoute, GRPCRoute, TCPRoute, etc.
# - BNKSecPolicy, BNKNetPolicy

resource "kubernetes_namespace_v1" "gateway" {
  count = var.create_gateway_namespace ? 1 : 0

  metadata {
    name = var.gateway_namespace

    labels = {
      "app.kubernetes.io/name"       = var.gateway_namespace
      "app.kubernetes.io/component"  = "gateway-api"
      "app.kubernetes.io/managed-by" = "terraform"
      "f5.com/product"               = "bnk"
    }

    annotations = {
      "description" = "Namespace for Gateway API resources"
    }
  }
}

# =============================================================================
# FAR IMAGE PULL SECRET (for all namespaces)
# =============================================================================
# Creates the F5 Artifact Registry pull secret in each namespace
# This is required for pulling BNK container images

resource "kubernetes_secret_v1" "far_secret_bnk" {
  count = var.create_far_secrets && var.far_docker_config != "" ? 1 : 0

  metadata {
    name      = var.far_secret_name
    namespace = kubernetes_namespace_v1.f5_bnk.metadata[0].name
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = var.far_docker_config
  }
}

resource "kubernetes_secret_v1" "far_secret_utils" {
  count = var.create_far_secrets && var.far_docker_config != "" ? 1 : 0

  metadata {
    name      = var.far_secret_name
    namespace = kubernetes_namespace_v1.f5_utils.metadata[0].name
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = var.far_docker_config
  }
}

resource "kubernetes_secret_v1" "far_secret_gateway" {
  count = var.create_far_secrets && var.create_gateway_namespace && var.far_docker_config != "" ? 1 : 0

  metadata {
    name      = var.far_secret_name
    namespace = kubernetes_namespace_v1.gateway[0].metadata[0].name
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = var.far_docker_config
  }
}

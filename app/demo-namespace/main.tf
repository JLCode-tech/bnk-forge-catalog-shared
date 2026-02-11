# bnk-forge-modules/app/demo-namespace/main.tf
# Demo Namespaces and ReferenceGrants for BNK Demo Apps

# =============================================================================
# NAMESPACES
# =============================================================================

resource "kubernetes_namespace_v1" "app_namespace" {
  metadata {
    name = var.app_namespace
    labels = {
      "app.kubernetes.io/part-of"    = "bnk-demo"
      "app.kubernetes.io/managed-by" = "opentofu"
    }
  }
}

resource "kubernetes_namespace_v1" "gateway_namespace" {
  metadata {
    name = var.gateway_namespace
    labels = {
      "app.kubernetes.io/part-of"    = "bnk-demo"
      "app.kubernetes.io/managed-by" = "opentofu"
    }
  }
}

resource "kubernetes_namespace_v1" "observability_namespace" {
  metadata {
    name = var.observability_namespace
    labels = {
      "app.kubernetes.io/part-of"    = "bnk-demo"
      "app.kubernetes.io/managed-by" = "opentofu"
    }
  }
}

# =============================================================================
# REFERENCE GRANTS
# =============================================================================
# Allow HTTPRoutes in gateway namespace to reference Services in app namespace

resource "kubernetes_manifest" "reference_grant_apps" {
  depends_on = [
    kubernetes_namespace_v1.app_namespace,
    kubernetes_namespace_v1.gateway_namespace,
  ]

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1beta1"
    kind       = "ReferenceGrant"

    metadata = {
      name      = "allow-gateway-to-apps"
      namespace = var.app_namespace
    }

    spec = {
      from = [
        {
          group     = "gateway.networking.k8s.io"
          kind      = "HTTPRoute"
          namespace = var.gateway_namespace
        }
      ]
      to = [
        {
          group = ""
          kind  = "Service"
        }
      ]
    }
  }
}

# Allow Gateway in gateway namespace to reference secrets in observability namespace
resource "kubernetes_manifest" "reference_grant_observability" {
  depends_on = [
    kubernetes_namespace_v1.gateway_namespace,
    kubernetes_namespace_v1.observability_namespace,
  ]

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1beta1"
    kind       = "ReferenceGrant"

    metadata = {
      name      = "allow-gateway-to-observability"
      namespace = var.observability_namespace
    }

    spec = {
      from = [
        {
          group     = "gateway.networking.k8s.io"
          kind      = "HTTPRoute"
          namespace = var.gateway_namespace
        }
      ]
      to = [
        {
          group = ""
          kind  = "Service"
        }
      ]
    }
  }
}

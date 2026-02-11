# bnk-forge-modules/app/demo-routes/main.tf
# HTTPRoutes for BNK Demo — Standard (:80) and Smart (:8080) listeners
#
# Validated against F5 BNK 2.2 docs (2026-02-12):
# - HTTPRoute: https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/bnk-gateway-api-httproute.html
# - Lanner PoC: lanner-bnk-poc/app/use-cases/uc1-llmaas/routing/10-httproute-standard.yaml
#                lanner-bnk-poc/app/use-cases/uc1-llmaas/routing/11-httproute-smart.yaml

locals {
  common_labels = {
    "app.kubernetes.io/component"  = "routing"
    "app.kubernetes.io/part-of"    = "bnk-demo"
    "app.kubernetes.io/managed-by" = "opentofu"
  }
}

# =============================================================================
# STANDARD ROUTE — :80 → litellm-proxy:4000 (direct, no iRule classification)
# =============================================================================

resource "kubernetes_manifest" "standard_route" {
  depends_on = [var.gateway_ready]

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"

    metadata = {
      name      = "demo-standard-route"
      namespace = var.gateway_namespace
      labels = merge(local.common_labels, {
        "app.kubernetes.io/name" = "demo-standard-route"
      })
    }

    spec = {
      parentRefs = [
        {
          name        = var.gateway_name
          sectionName = "standard-http"
        }
      ]
      rules = [
        {
          matches = [
            {
              path = {
                type  = "PathPrefix"
                value = "/"
              }
            }
          ]
          backendRefs = [
            {
              name      = var.backend_service_name
              namespace = var.app_namespace
              port      = var.backend_service_port
              weight    = 1
            }
          ]
        }
      ]
    }
  }
}

# =============================================================================
# SMART ROUTE — :8080 → litellm-proxy:4000 (with SmartLLM iRule classification)
# =============================================================================

resource "kubernetes_manifest" "smart_route" {
  count      = var.enable_smart_route ? 1 : 0
  depends_on = [var.gateway_ready]

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"

    metadata = {
      name      = "demo-smart-route"
      namespace = var.gateway_namespace
      labels = merge(local.common_labels, {
        "app.kubernetes.io/name" = "demo-smart-route"
      })
    }

    spec = {
      parentRefs = [
        {
          name        = var.gateway_name
          sectionName = "smart-http"
        }
      ]
      rules = [
        {
          matches = [
            {
              path = {
                type  = "PathPrefix"
                value = "/"
              }
            }
          ]
          backendRefs = [
            {
              name      = var.backend_service_name
              namespace = var.app_namespace
              port      = var.backend_service_port
              weight    = 1
            }
          ]
        }
      ]
    }
  }
}

# =============================================================================
# VERIFICATION
# =============================================================================

resource "null_resource" "verify_routes" {
  depends_on = [
    kubernetes_manifest.standard_route,
    kubernetes_manifest.smart_route,
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Verifying Demo Routes ==="
      kubectl get httproutes -n ${var.gateway_namespace} -l app.kubernetes.io/part-of=bnk-demo
      echo ""
      echo "=== Route Status ==="
      for route in demo-standard-route demo-smart-route; do
        echo "--- $route ---"
        kubectl get httproute $route -n ${var.gateway_namespace} -o jsonpath='{.status.parents[*].conditions[*].reason}' 2>/dev/null || echo "not found"
      done
      echo ""
      echo "Routes verification complete"
    EOT
  }
}

# bnk-forge-modules/app/demo-routes/main.tf
# Demo HTTPRoutes — Web, API (with canary), Health, AI (optional)

# =============================================================================
# WEB ROUTE — / → demo-web:80
# =============================================================================

resource "kubernetes_manifest" "web_route" {
  depends_on = [var.gateway_ready]

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"

    metadata = {
      name      = "web-route"
      namespace = var.gateway_namespace
      labels = {
        "app.kubernetes.io/name"       = "web-route"
        "app.kubernetes.io/component"  = "routing"
        "app.kubernetes.io/part-of"    = "bnk-demo"
        "app.kubernetes.io/managed-by" = "opentofu"
      }
    }

    spec = {
      parentRefs = [
        {
          name        = var.gateway_name
          sectionName = "http"
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
              name      = "demo-web"
              namespace = var.app_namespace
              port      = 80
              weight    = 1
            }
          ]
        }
      ]
    }
  }
}

# =============================================================================
# API ROUTE — /api/* → demo-api:8080 (with optional canary to demo-backend)
# =============================================================================

resource "kubernetes_manifest" "api_route" {
  depends_on = [var.gateway_ready]

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"

    metadata = {
      name      = "api-route"
      namespace = var.gateway_namespace
      labels = {
        "app.kubernetes.io/name"       = "api-route"
        "app.kubernetes.io/component"  = "routing"
        "app.kubernetes.io/part-of"    = "bnk-demo"
        "app.kubernetes.io/managed-by" = "opentofu"
      }
    }

    spec = {
      parentRefs = [
        {
          name        = var.gateway_name
          sectionName = "http"
        }
      ]
      rules = concat(
        # Rule 1: Header-based canary routing (X-Canary: true → backend)
        var.enable_canary_routing ? [
          {
            matches = [
              {
                path = {
                  type  = "PathPrefix"
                  value = "/api"
                }
                headers = [
                  {
                    type  = "Exact"
                    name  = "X-Canary"
                    value = "true"
                  }
                ]
              }
            ]
            backendRefs = [
              {
                name      = "demo-backend"
                namespace = var.app_namespace
                port      = 8080
                weight    = 1
              }
            ]
          }
        ] : [],
        # Rule 2: Default API routing with weighted backends
        [
          {
            matches = [
              {
                path = {
                  type  = "PathPrefix"
                  value = "/api"
                }
              }
            ]
            backendRefs = concat(
              [
                {
                  name      = "demo-api"
                  namespace = var.app_namespace
                  port      = 8080
                  weight    = 100 - (var.enable_canary_routing ? var.canary_weight : 0)
                }
              ],
              var.enable_canary_routing ? [
                {
                  name      = "demo-backend"
                  namespace = var.app_namespace
                  port      = 8080
                  weight    = var.canary_weight
                }
              ] : []
            )
          }
        ]
      )
    }
  }
}

# =============================================================================
# HEALTH ROUTE — /health → demo-api:8080
# =============================================================================

resource "kubernetes_manifest" "health_route" {
  depends_on = [var.gateway_ready]

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"

    metadata = {
      name      = "health-route"
      namespace = var.gateway_namespace
      labels = {
        "app.kubernetes.io/name"       = "health-route"
        "app.kubernetes.io/component"  = "routing"
        "app.kubernetes.io/part-of"    = "bnk-demo"
        "app.kubernetes.io/managed-by" = "opentofu"
      }
    }

    spec = {
      parentRefs = [
        {
          name        = var.gateway_name
          sectionName = "http"
        }
      ]
      rules = [
        {
          matches = [
            {
              path = {
                type  = "Exact"
                value = "/health"
              }
            }
          ]
          backendRefs = [
            {
              name      = "demo-api"
              namespace = var.app_namespace
              port      = 8080
              weight    = 1
            }
          ]
        }
      ]
    }
  }
}

# =============================================================================
# AI ROUTE (Optional) — /v1/chat/* → demo-api:8080 on smart listener
# =============================================================================

resource "kubernetes_manifest" "ai_route" {
  count      = var.enable_ai_route ? 1 : 0
  depends_on = [var.gateway_ready]

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"

    metadata = {
      name      = "ai-route"
      namespace = var.gateway_namespace
      labels = {
        "app.kubernetes.io/name"       = "ai-route"
        "app.kubernetes.io/component"  = "routing"
        "app.kubernetes.io/part-of"    = "bnk-demo"
        "app.kubernetes.io/managed-by" = "opentofu"
      }
    }

    spec = {
      parentRefs = [
        {
          name        = var.gateway_name
          sectionName = "smart"
        }
      ]
      rules = [
        {
          matches = [
            {
              path = {
                type  = "PathPrefix"
                value = "/v1/chat"
              }
            }
          ]
          backendRefs = [
            {
              name      = "demo-api"
              namespace = var.app_namespace
              port      = 8080
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
    kubernetes_manifest.web_route,
    kubernetes_manifest.api_route,
    kubernetes_manifest.health_route,
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Verifying Demo Routes ==="
      kubectl get httproutes -n ${var.gateway_namespace} -l app.kubernetes.io/part-of=bnk-demo
      echo "Routes verification complete"
    EOT
  }
}

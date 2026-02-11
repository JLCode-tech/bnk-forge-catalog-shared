# bnk-forge-modules/app/demo-gateway/main.tf
# Demo BNK Gateway with multiple listeners

# =============================================================================
# LOCALS
# =============================================================================

locals {
  # Build listeners list dynamically based on enabled features
  base_listeners = [
    {
      name     = "http"
      protocol = "HTTP"
      port     = 80
      allowedRoutes = {
        namespaces = {
          from = "All"
        }
      }
    }
  ]

  https_listener = var.enable_https_listener ? [
    {
      name     = "https"
      protocol = "HTTPS"
      port     = 443
      tls = {
        mode = "Terminate"
        certificateRefs = [
          {
            name = "demo-gw-tls"
            kind = "Secret"
          }
        ]
      }
      allowedRoutes = {
        namespaces = {
          from = "All"
        }
      }
    }
  ] : []

  smart_listener = var.enable_smart_listener ? [
    {
      name     = "smart"
      protocol = "HTTP"
      port     = 8080
      allowedRoutes = {
        namespaces = {
          from = "All"
        }
      }
    }
  ] : []

  all_listeners = concat(local.base_listeners, local.https_listener, local.smart_listener)
}

# =============================================================================
# SELF-SIGNED TLS CERTIFICATE (if HTTPS enabled and cert-manager available)
# =============================================================================

resource "kubernetes_manifest" "tls_certificate" {
  count = var.enable_https_listener ? 1 : 0

  depends_on = [var.namespaces_ready]

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"

    metadata = {
      name      = "demo-gw-tls"
      namespace = var.gateway_namespace
      labels = {
        "app.kubernetes.io/name"       = "demo-gw-tls"
        "app.kubernetes.io/part-of"    = "bnk-demo"
        "app.kubernetes.io/managed-by" = "opentofu"
      }
    }

    spec = {
      secretName = "demo-gw-tls"
      issuerRef = {
        name = var.cluster_issuer_name
        kind = "ClusterIssuer"
      }
      dnsNames = [
        "demo-gw.${var.gateway_namespace}.svc.cluster.local",
        "demo.bnk.local",
        "*.demo.bnk.local"
      ]
      duration    = "2160h"
      renewBefore = "360h"
    }
  }
}

# =============================================================================
# BNK GATEWAY
# =============================================================================

resource "kubernetes_manifest" "gateway" {
  depends_on = [var.namespaces_ready]

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "Gateway"

    metadata = {
      name      = var.gateway_name
      namespace = var.gateway_namespace
      labels = {
        "app.kubernetes.io/name"       = var.gateway_name
        "app.kubernetes.io/component"  = "gateway"
        "app.kubernetes.io/part-of"    = "bnk-demo"
        "app.kubernetes.io/managed-by" = "opentofu"
      }
    }

    spec = {
      gatewayClassName = var.gatewayclass_name
      listeners        = local.all_listeners
    }
  }
}

# =============================================================================
# WAIT FOR GATEWAY READINESS
# =============================================================================

resource "time_sleep" "wait_for_gateway" {
  depends_on      = [kubernetes_manifest.gateway]
  create_duration = "30s"
}

resource "null_resource" "verify_gateway" {
  depends_on = [time_sleep.wait_for_gateway]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Verifying Demo Gateway ${var.gateway_name} ==="
      kubectl get gateway ${var.gateway_name} -n ${var.gateway_namespace} || echo "Gateway not found yet"
      kubectl wait --for=condition=Programmed gateway/${var.gateway_name} -n ${var.gateway_namespace} --timeout=120s || echo "Gateway not yet programmed — TMM may need time to allocate"
      echo "=== Gateway Status ==="
      kubectl get gateway ${var.gateway_name} -n ${var.gateway_namespace} -o jsonpath='{.status}' | python3 -m json.tool 2>/dev/null || echo "No status available yet"
      echo "Gateway verification complete"
    EOT
  }
}

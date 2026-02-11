# bnk-forge-modules/app/demo-gateway/main.tf
# BNK Gateway with static VIP and dual listeners (standard + smart)
#
# Validated against F5 BNK 2.2 docs (2026-02-12):
# - Gateway CR: https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/bnk-gateway-api-gateway.html
# - F5BnkGateway IPAM: https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/bnk-bnkgateway.html
# - Lanner PoC: lanner-bnk-poc/app/use-cases/uc1-llmaas/gateways/llmaas-gw.yaml

# =============================================================================
# LOCALS
# =============================================================================

locals {
  common_labels = {
    "app.kubernetes.io/name"       = var.gateway_name
    "app.kubernetes.io/component"  = "gateway"
    "app.kubernetes.io/part-of"    = "bnk-demo"
    "app.kubernetes.io/managed-by" = "opentofu"
  }

  # Build listeners list: standard-http always, smart-http optional
  base_listeners = [
    {
      name     = "standard-http"
      protocol = "HTTP"
      port     = 80
      allowedRoutes = {
        namespaces = {
          from = "All"
        }
      }
    }
  ]

  smart_listener = var.enable_smart_listener ? [
    {
      name     = "smart-http"
      protocol = "HTTP"
      port     = 8080
      allowedRoutes = {
        namespaces = {
          from = "All"
        }
      }
    }
  ] : []

  all_listeners = concat(local.base_listeners, local.smart_listener)

  # Build Gateway spec dynamically based on whether VIP and parametersRef are set
  gateway_addresses = var.gateway_vip != "" ? [
    {
      type  = "IPAddress"
      value = var.gateway_vip
    }
  ] : []

  # parametersRef links to the F5BnkGateway for IPAM validation
  gateway_infrastructure = var.bnkgateway_name != "" ? {
    parametersRef = {
      group = "k8s.f5net.com"
      kind  = "F5BnkGateway"
      name  = var.bnkgateway_name
    }
  } : null
}

# =============================================================================
# BNK GATEWAY
# =============================================================================

resource "kubernetes_manifest" "gateway" {
  depends_on = [var.namespaces_ready]

  manifest = merge(
    {
      apiVersion = "gateway.networking.k8s.io/v1"
      kind       = "Gateway"

      metadata = {
        name      = var.gateway_name
        namespace = var.gateway_namespace
        labels    = local.common_labels
      }
    },
    {
      spec = merge(
        {
          gatewayClassName = var.gatewayclass_name
          listeners        = local.all_listeners
        },
        length(local.gateway_addresses) > 0 ? { addresses = local.gateway_addresses } : {},
        local.gateway_infrastructure != null ? { infrastructure = local.gateway_infrastructure } : {}
      )
    }
  )
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
      kubectl get gateway ${var.gateway_name} -n ${var.gateway_namespace} -o wide || echo "Gateway not found yet"
      echo ""
      echo "=== Waiting for Programmed condition ==="
      kubectl wait --for=condition=Programmed gateway/${var.gateway_name} -n ${var.gateway_namespace} --timeout=120s || echo "Gateway not yet programmed — TMM may need time"
      echo ""
      echo "=== Gateway Status ==="
      kubectl get gateway ${var.gateway_name} -n ${var.gateway_namespace} -o jsonpath='{.status}' | python3 -m json.tool 2>/dev/null || echo "No status yet"
      echo ""
      echo "=== VIP Address ==="
      kubectl get gateway ${var.gateway_name} -n ${var.gateway_namespace} -o jsonpath='{.status.addresses[*].value}' || echo "No VIP assigned yet"
      echo ""
      echo "=== Listener Status ==="
      kubectl get gateway ${var.gateway_name} -n ${var.gateway_namespace} -o jsonpath='{.status.listeners[*].name}' || echo "No listeners ready yet"
      echo ""
      echo "Gateway verification complete"
    EOT
  }
}

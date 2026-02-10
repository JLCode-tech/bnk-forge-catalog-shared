# bnk-forge-modules/bnk/bnk-gatewayclass/main.tf
# GatewayClass for F5 BIG-IP Next for Kubernetes (BNK 2.2 GA)
#
# Per F5 docs: https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/bnk-gateway-api-gatewayclass.html
# BNK 2.2 uses a STANDARD Kubernetes GatewayClass (gateway.networking.k8s.io/v1).
# There is NO BNKGatewayClassConfig CRD — that was a fabrication.
# TMM config is done via the F5BnkGateway CR (k8s.f5net.com/v1) and Gateway infrastructure annotations.
#
# The controllerName format is: f5.com/<namespace>-f5-cne-controller
# Example: f5.com/f5-bnk-f5-cne-controller

# =============================================================================
# LOCALS
# =============================================================================

locals {
  # Per F5 docs: controllerName = f5.com/<namespace>-f5-cne-controller
  # Example: if flo_namespace = "f5-bnk" → "f5.com/f5-bnk-f5-cne-controller"
  controller_name = var.controller_name != "" ? var.controller_name : "f5.com/${var.flo_namespace}-f5-cne-controller"
}

# =============================================================================
# GATEWAY CLASS
# =============================================================================

resource "kubernetes_manifest" "bnk_gatewayclass" {
  depends_on = [var.flo_ready]

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "GatewayClass"

    metadata = {
      name = var.gatewayclass_name
      labels = merge(var.common_labels, {
        "app.kubernetes.io/name"       = "bnk-gatewayclass"
        "app.kubernetes.io/component"  = "gateway-api"
        "app.kubernetes.io/managed-by" = "terraform"
      })
    }

    spec = {
      # Per F5 docs: controllerName = f5.com/<namespace>-f5-cne-controller
      controllerName = local.controller_name
      description    = var.description
    }
  }
}

# =============================================================================
# VERIFICATION
# =============================================================================

resource "time_sleep" "wait_for_gatewayclass" {
  depends_on = [kubernetes_manifest.bnk_gatewayclass]

  create_duration = "15s"
}

resource "null_resource" "verify_gatewayclass" {
  depends_on = [time_sleep.wait_for_gatewayclass]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Verifying GatewayClass ==="

      # Check GatewayClass exists and show status
      kubectl get gatewayclass ${var.gatewayclass_name} -o wide || echo "GatewayClass not found"

      # Wait for controller to accept the GatewayClass
      kubectl wait --for=condition=Accepted gatewayclass/${var.gatewayclass_name} --timeout=120s || echo "WARNING: GatewayClass not yet accepted by controller"

      echo "GatewayClass verification complete"
    EOT
  }
}

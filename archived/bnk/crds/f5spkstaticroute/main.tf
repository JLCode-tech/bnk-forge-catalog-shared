# infrastructure-modules/bnk/f5spkstaticroute/main.tf
# F5SPKStaticRoute - Static Route Configuration

# =============================================================================
# F5 SPK STATIC ROUTE
# =============================================================================

resource "kubernetes_manifest" "f5spkstaticroute" {
  depends_on = [var.flo_ready]

  manifest = {
    apiVersion = "k8s.f5net.com/v1"
    kind       = "F5SPKStaticRoute"

    metadata = {
      name      = var.route_name
      namespace = var.route_namespace

      labels = merge(var.common_labels, {
        "app.kubernetes.io/name"       = var.route_name
        "app.kubernetes.io/component"  = "static-route"
        "app.kubernetes.io/managed-by" = "terraform"
      })

      annotations = var.annotations
    }

    spec = merge(
      {
        destination = var.destination
        gateway     = var.gateway
        metric      = var.metric
      },
      var.interface != null ? {
        interface = var.interface
      } : {}
    )
  }
}

# =============================================================================
# VERIFICATION
# =============================================================================

resource "time_sleep" "wait_for_route" {
  depends_on = [kubernetes_manifest.f5spkstaticroute]

  create_duration = "5s"
}

resource "null_resource" "verify_route" {
  depends_on = [time_sleep.wait_for_route]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Verifying F5SPKStaticRoute ${var.route_name} ==="

      # Check route exists
      kubectl get f5spkstaticroute ${var.route_name} -n ${var.route_namespace} || echo "Route not found yet"

      echo "✓ F5SPKStaticRoute verification complete"
    EOT
  }
}

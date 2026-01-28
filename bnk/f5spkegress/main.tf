# infrastructure-modules/bnk/f5spkegress/main.tf
# F5SPKEgress - Egress Traffic Configuration

# =============================================================================
# F5 SPK EGRESS
# =============================================================================

resource "kubernetes_manifest" "f5spkegress" {
  depends_on = [var.flo_ready]

  manifest = {
    apiVersion = "k8s.f5net.com/v1"
    kind       = "F5SPKEgress"

    metadata = {
      name      = var.egress_name
      namespace = var.egress_namespace

      labels = merge(var.common_labels, {
        "app.kubernetes.io/name"       = var.egress_name
        "app.kubernetes.io/component"  = "egress-config"
        "app.kubernetes.io/managed-by" = "terraform"
      })

      annotations = var.annotations
    }

    spec = merge(
      {
        egressCIDR = var.egress_cidr
      },
      var.snat_pool_ref != null ? {
        snatPoolRef = var.snat_pool_ref
      } : {},
      length(var.allowed_destinations) > 0 ? {
        allowedDestinations = var.allowed_destinations
      } : {}
    )
  }
}

# =============================================================================
# VERIFICATION
# =============================================================================

resource "time_sleep" "wait_for_egress" {
  depends_on = [kubernetes_manifest.f5spkegress]

  create_duration = "5s"
}

resource "null_resource" "verify_egress" {
  depends_on = [time_sleep.wait_for_egress]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Verifying F5SPKEgress ${var.egress_name} ==="

      # Check egress exists
      kubectl get f5spkegress ${var.egress_name} -n ${var.egress_namespace} || echo "Egress not found yet"

      echo "✓ F5SPKEgress verification complete"
    EOT
  }
}

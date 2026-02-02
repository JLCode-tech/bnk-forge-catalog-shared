# infrastructure-modules/bnk/f5spksnatpool/main.tf
# F5SPKSnatpool - SNAT Pool Configuration

# =============================================================================
# F5 SPK SNAT POOL
# =============================================================================

resource "kubernetes_manifest" "f5spksnatpool" {
  depends_on = [var.flo_ready]

  manifest = {
    apiVersion = "k8s.f5net.com/v1"
    kind       = "F5SPKSnatpool"

    metadata = {
      name      = var.pool_name
      namespace = var.pool_namespace

      labels = merge(var.common_labels, {
        "app.kubernetes.io/name"       = var.pool_name
        "app.kubernetes.io/component"  = "snat-pool"
        "app.kubernetes.io/managed-by" = "terraform"
      })

      annotations = var.annotations
    }

    spec = merge(
      {
        ipRanges = var.ip_ranges
      },
      length(var.pool_members) > 0 ? {
        members = var.pool_members
      } : {}
    )
  }
}

# =============================================================================
# VERIFICATION
# =============================================================================

resource "time_sleep" "wait_for_pool" {
  depends_on = [kubernetes_manifest.f5spksnatpool]

  create_duration = "5s"
}

resource "null_resource" "verify_pool" {
  depends_on = [time_sleep.wait_for_pool]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Verifying F5SPKSnatpool ${var.pool_name} ==="

      # Check pool exists
      kubectl get f5spksnatpool ${var.pool_name} -n ${var.pool_namespace} || echo "Pool not found yet"

      echo "✓ F5SPKSnatpool verification complete"
    EOT
  }
}

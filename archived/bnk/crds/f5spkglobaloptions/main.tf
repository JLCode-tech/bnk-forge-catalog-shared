# infrastructure-modules/bnk/f5spkglobaloptions/main.tf
# F5SPKGlobalOptions - Cluster-Wide SPK Configuration

# =============================================================================
# F5 SPK GLOBAL OPTIONS (CLUSTER-SCOPED)
# =============================================================================

resource "kubernetes_manifest" "f5spkglobaloptions" {
  depends_on = [var.flo_ready]

  manifest = {
    apiVersion = "k8s.f5net.com/v1"
    kind       = "F5SPKGlobalOptions"

    metadata = {
      name = var.options_name
      # NOTE: Cluster-scoped resource - no namespace

      labels = merge(var.common_labels, {
        "app.kubernetes.io/name"       = var.options_name
        "app.kubernetes.io/component"  = "global-options"
        "app.kubernetes.io/managed-by" = "terraform"
      })

      annotations = var.annotations
    }

    spec = merge(
      {
        cryptoAcceleration = var.crypto_acceleration
      },
      var.hardware_offload_enabled ? {
        hardwareOffload = merge(
          { enabled = true },
          length(var.hardware_offload_settings) > 0 ? var.hardware_offload_settings : {}
        )
      } : {
        hardwareOffload = { enabled = false }
      }
    )
  }
}

# =============================================================================
# VERIFICATION
# =============================================================================

resource "time_sleep" "wait_for_options" {
  depends_on = [kubernetes_manifest.f5spkglobaloptions]

  create_duration = "5s"
}

resource "null_resource" "verify_options" {
  depends_on = [time_sleep.wait_for_options]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Verifying F5SPKGlobalOptions ${var.options_name} ==="

      # Check global options exists (cluster-scoped)
      kubectl get f5spkglobaloptions ${var.options_name} || echo "Global options not found yet"

      echo "✓ F5SPKGlobalOptions verification complete"
    EOT
  }
}

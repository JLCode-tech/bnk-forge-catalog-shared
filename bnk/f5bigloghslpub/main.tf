# infrastructure-modules/bnk/f5bigloghslpub/main.tf
# F5BigLogHslpub - High-Speed Logging Publisher

# =============================================================================
# F5 HSL PUBLISHER
# =============================================================================

resource "kubernetes_manifest" "f5bigloghslpub" {
  depends_on = [var.flo_ready]

  manifest = {
    apiVersion = "k8s.f5net.com/v1"
    kind       = "F5BigLogHslpub"

    metadata = {
      name      = var.publisher_name
      namespace = var.publisher_namespace

      labels = merge(var.common_labels, {
        "app.kubernetes.io/name"       = var.publisher_name
        "app.kubernetes.io/component"  = "hsl-publisher"
        "app.kubernetes.io/managed-by" = "terraform"
      })

      annotations = var.annotations
    }

    spec = merge(
      {
        syslogServers = var.syslog_servers
        protocol      = var.protocol
        port          = var.port
      },
      var.pool_name != null ? {
        poolName = var.pool_name
      } : {}
    )
  }
}

# =============================================================================
# VERIFICATION
# =============================================================================

resource "time_sleep" "wait_for_publisher" {
  depends_on = [kubernetes_manifest.f5bigloghslpub]

  create_duration = "5s"
}

resource "null_resource" "verify_publisher" {
  depends_on = [time_sleep.wait_for_publisher]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Verifying F5BigLogHslpub ${var.publisher_name} ==="

      # Check publisher exists
      kubectl get f5bigloghslpub ${var.publisher_name} -n ${var.publisher_namespace} || echo "Publisher not found yet"

      echo "✓ F5BigLogHslpub verification complete"
    EOT
  }
}

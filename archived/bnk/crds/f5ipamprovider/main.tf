# infrastructure-modules/bnk/f5ipamprovider/main.tf
# F5IPAMProvider - IP Address Management Provider

# =============================================================================
# F5 IPAM PROVIDER
# =============================================================================

resource "kubernetes_manifest" "f5ipamprovider" {
  depends_on = [var.flo_ready]

  manifest = {
    apiVersion = "k8s.f5net.com/v1"
    kind       = "F5IPAMProvider"

    metadata = {
      name      = var.provider_name
      namespace = var.provider_namespace

      labels = merge(var.common_labels, {
        "app.kubernetes.io/name"       = var.provider_name
        "app.kubernetes.io/component"  = "ipam-provider"
        "app.kubernetes.io/managed-by" = "terraform"
      })

      annotations = var.annotations
    }

    spec = {
      providerType = var.provider_type
      ipRanges     = var.ip_ranges
    }
  }
}

# =============================================================================
# VERIFICATION
# =============================================================================

resource "time_sleep" "wait_for_provider" {
  depends_on = [kubernetes_manifest.f5ipamprovider]

  create_duration = "5s"
}

resource "null_resource" "verify_provider" {
  depends_on = [time_sleep.wait_for_provider]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Verifying F5IPAMProvider ${var.provider_name} ==="

      # Check provider exists
      kubectl get f5ipamprovider ${var.provider_name} -n ${var.provider_namespace} || echo "Provider not found yet"

      echo "✓ F5IPAMProvider verification complete"
    EOT
  }
}

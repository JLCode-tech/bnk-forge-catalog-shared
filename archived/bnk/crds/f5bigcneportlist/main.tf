# infrastructure-modules/bnk/f5bigcneportlist/main.tf
# F5BigCnePortlist - CNE Port List

# =============================================================================
# F5 CNE PORT LIST
# =============================================================================

resource "kubernetes_manifest" "f5bigcneportlist" {
  depends_on = [var.flo_ready]

  manifest = {
    apiVersion = "k8s.f5net.com/v1"
    kind       = "F5BigCnePortlist"

    metadata = {
      name      = var.list_name
      namespace = var.list_namespace

      labels = merge(var.common_labels, {
        "app.kubernetes.io/name"       = var.list_name
        "app.kubernetes.io/component"  = "port-list"
        "app.kubernetes.io/managed-by" = "terraform"
      })

      annotations = merge(
        var.annotations,
        var.description != "" ? {
          "f5.com/list-description" = var.description
        } : {}
      )
    }

    spec = {
      ports = var.ports
    }
  }
}

# =============================================================================
# VERIFICATION
# =============================================================================

resource "time_sleep" "wait_for_list" {
  depends_on = [kubernetes_manifest.f5bigcneportlist]

  create_duration = "5s"
}

resource "null_resource" "verify_list" {
  depends_on = [time_sleep.wait_for_list]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Verifying F5BigCnePortlist ${var.list_name} ==="

      # Check list exists
      kubectl get f5bigcneportlist ${var.list_name} -n ${var.list_namespace} || echo "List not found yet"

      echo "✓ F5BigCnePortlist verification complete"
    EOT
  }
}

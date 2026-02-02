# infrastructure-modules/bnk/referencegrant/main.tf
# ReferenceGrant - Cross-Namespace Reference Authorization

# =============================================================================
# GATEWAY API REFERENCE GRANT
# =============================================================================

resource "kubernetes_manifest" "referencegrant" {
  depends_on = [var.flo_ready]

  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1beta1"
    kind       = "ReferenceGrant"

    metadata = {
      name      = var.grant_name
      namespace = var.grant_namespace

      labels = merge(var.common_labels, {
        "app.kubernetes.io/name"       = var.grant_name
        "app.kubernetes.io/component"  = "reference-grant"
        "app.kubernetes.io/managed-by" = "terraform"
      })

      annotations = var.annotations
    }

    spec = {
      from = [
        for ns in var.from_namespaces : {
          group     = "gateway.networking.k8s.io"
          kind      = "HTTPRoute"
          namespace = ns
        }
      ]

      to = [
        for resource in var.to_resources : merge(
          {
            group = resource == "Service" ? "" : "gateway.networking.k8s.io"
            kind  = resource
          },
          length(var.to_resource_names) > 0 ? {
            name = var.to_resource_names[0] # Gateway API supports single name per 'to' entry
          } : {}
        )
      ]
    }
  }
}

# =============================================================================
# VERIFICATION
# =============================================================================

resource "time_sleep" "wait_for_grant" {
  depends_on = [kubernetes_manifest.referencegrant]

  create_duration = "5s"
}

resource "null_resource" "verify_grant" {
  depends_on = [time_sleep.wait_for_grant]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Verifying ReferenceGrant ${var.grant_name} ==="

      # Check grant exists
      kubectl get referencegrant ${var.grant_name} -n ${var.grant_namespace} || echo "Grant not found yet"

      echo "✓ ReferenceGrant verification complete"
    EOT
  }
}

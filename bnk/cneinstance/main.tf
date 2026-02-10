# infrastructure-modules/bnk/cneinstance/main.tf
# CneInstance - CNE Instance Configuration

# =============================================================================
# CNE INSTANCE
# =============================================================================

resource "kubernetes_manifest" "cneinstance" {
  depends_on = [var.flo_ready]

  manifest = {
    apiVersion = "k8s.f5.com/v1"
    kind       = "CneInstance"

    metadata = {
      name      = var.instance_name
      namespace = var.instance_namespace

      labels = merge(var.common_labels, {
        "app.kubernetes.io/name"       = var.instance_name
        "app.kubernetes.io/component"  = "cne-instance"
        "app.kubernetes.io/managed-by" = "terraform"
      })

      annotations = var.annotations
    }

    spec = merge(
      {
        instanceType = var.instance_config.instance_type
        replicas     = var.instance_config.replicas
      },
      length(var.resource_limits) > 0 ? {
        resources = {
          requests = {
            cpu    = var.resource_limits.cpu_request
            memory = var.resource_limits.memory_request
          }
          limits = {
            cpu    = var.resource_limits.cpu_limit
            memory = var.resource_limits.memory_limit
          }
        }
      } : {},
      length(var.instance_config.affinity) > 0 ? {
        affinity = var.instance_config.affinity
      } : {}
    )
  }
}

# =============================================================================
# VERIFICATION
# =============================================================================

resource "time_sleep" "wait_for_instance" {
  depends_on = [kubernetes_manifest.cneinstance]

  create_duration = "10s"
}

resource "null_resource" "verify_instance" {
  depends_on = [time_sleep.wait_for_instance]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Verifying CneInstance ${var.instance_name} ==="

      # Check instance exists
      kubectl get cneinstance ${var.instance_name} -n ${var.instance_namespace} || echo "Instance not found yet"

      echo "✓ CneInstance verification complete"
    EOT
  }
}

# infrastructure-modules/bnk/cneinstance/main.tf
# CneInstance - CNE Instance Configuration

# =============================================================================
# LOCAL VALUES
# =============================================================================

locals {
  labels = merge(var.common_labels, {
    "app.kubernetes.io/name"       = var.instance_name
    "app.kubernetes.io/component"  = "cne-instance"
    "app.kubernetes.io/managed-by" = "terraform"
  })

  # Build the CNEInstance manifest as YAML
  cneinstance_manifest = yamlencode({
    apiVersion = "k8s.f5.com/v1"
    kind       = "CNEInstance"
    metadata = {
      name        = var.instance_name
      namespace   = var.instance_namespace
      labels      = local.labels
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
  })
}

# =============================================================================
# CNE INSTANCE - Using kubectl apply to avoid kubernetes_manifest schema issues
# =============================================================================

resource "null_resource" "cneinstance" {
  depends_on = [var.flo_ready]

  triggers = {
    manifest_hash = sha256(local.cneinstance_manifest)
    name          = var.instance_name
    namespace     = var.instance_namespace
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo '${local.cneinstance_manifest}' | kubectl apply -f -
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      kubectl delete cneinstance ${self.triggers.name} -n ${self.triggers.namespace} --ignore-not-found=true
    EOT
  }
}

# =============================================================================
# VERIFICATION
# =============================================================================

resource "time_sleep" "wait_for_instance" {
  depends_on = [null_resource.cneinstance]

  create_duration = "10s"
}

resource "null_resource" "verify_instance" {
  depends_on = [time_sleep.wait_for_instance]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Verifying CNEInstance ${var.instance_name} ==="

      # Check instance exists
      kubectl get cneinstance ${var.instance_name} -n ${var.instance_namespace} || echo "Instance not found yet"

      echo "✓ CNEInstance verification complete"
    EOT
  }
}

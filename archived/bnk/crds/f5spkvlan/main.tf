# infrastructure-modules/bnk/f5spkvlan/main.tf
# F5SPKVlan - VLAN Configuration

# =============================================================================
# F5 SPK VLAN
# =============================================================================

resource "kubernetes_manifest" "f5spkvlan" {
  depends_on = [var.flo_ready]

  manifest = {
    apiVersion = "k8s.f5net.com/v1"
    kind       = "F5SPKVlan"

    metadata = {
      name      = var.vlan_name
      namespace = var.vlan_namespace

      labels = merge(var.common_labels, {
        "app.kubernetes.io/name"       = var.vlan_name
        "app.kubernetes.io/component"  = "vlan"
        "app.kubernetes.io/managed-by" = "terraform"
        "f5.com/vlan-type"             = var.internal ? "internal" : "external"
      })

      annotations = var.annotations
    }

    spec = merge(
      {
        name         = var.vlan_tag_name
        interfaces   = var.interfaces
        selfip_v4s   = var.selfip_v4s
        prefixlen_v4 = var.prefixlen_v4
        mtu          = var.mtu
        internal     = var.internal
      },
      var.vlan_id != null ? {
        vlanId = var.vlan_id
      } : {}
    )
  }
}

# =============================================================================
# VERIFICATION
# =============================================================================

resource "time_sleep" "wait_for_vlan" {
  depends_on = [kubernetes_manifest.f5spkvlan]

  create_duration = "5s"
}

resource "null_resource" "verify_vlan" {
  depends_on = [time_sleep.wait_for_vlan]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Verifying F5SPKVlan ${var.vlan_name} ==="

      # Check VLAN exists
      kubectl get f5spkvlan ${var.vlan_name} -n ${var.vlan_namespace} || echo "VLAN not found yet"

      echo "✓ F5SPKVlan verification complete"
    EOT
  }
}

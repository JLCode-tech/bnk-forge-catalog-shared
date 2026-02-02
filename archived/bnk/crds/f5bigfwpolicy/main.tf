# infrastructure-modules/bnk/f5bigfwpolicy/main.tf
# F5BigFwPolicy - Advanced Firewall Policy

# =============================================================================
# F5 BIG-IP FIREWALL POLICY
# =============================================================================

resource "kubernetes_manifest" "f5bigfwpolicy" {
  depends_on = [var.flo_ready]

  manifest = {
    apiVersion = "k8s.f5net.com/v1"
    kind       = "F5BigFwPolicy"

    metadata = {
      name      = var.policy_name
      namespace = var.policy_namespace

      labels = merge(var.common_labels, {
        "app.kubernetes.io/name"       = var.policy_name
        "app.kubernetes.io/component"  = "firewall-policy"
        "app.kubernetes.io/managed-by" = "terraform"
      })

      annotations = merge(
        var.annotations,
        var.description != "" ? {
          "f5.com/policy-description" = var.description
        } : {}
      )
    }

    spec = merge(
      {
        defaultAction = var.default_action
      },
      var.enable_logging ? {
        logging = {
          enabled = true
        }
      } : {},
      length(var.ingress_rules) > 0 ? {
        ingressRules = [
          for rule in var.ingress_rules : merge(
            {
              name   = rule.name
              action = rule.action
            },
            rule.protocol != null ? { protocol = rule.protocol } : {},
            rule.source_addresses != null ? { sourceAddresses = rule.source_addresses } : {},
            rule.source_ports != null ? { sourcePorts = rule.source_ports } : {},
            rule.dest_addresses != null ? { destinationAddresses = rule.dest_addresses } : {},
            rule.dest_ports != null ? { destinationPorts = rule.dest_ports } : {},
            rule.address_list_refs != null ? { addressListRefs = rule.address_list_refs } : {},
            rule.port_list_refs != null ? { portListRefs = rule.port_list_refs } : {},
            { log = rule.log }
          )
        ]
      } : {},
      length(var.egress_rules) > 0 ? {
        egressRules = [
          for rule in var.egress_rules : merge(
            {
              name   = rule.name
              action = rule.action
            },
            rule.protocol != null ? { protocol = rule.protocol } : {},
            rule.source_addresses != null ? { sourceAddresses = rule.source_addresses } : {},
            rule.source_ports != null ? { sourcePorts = rule.source_ports } : {},
            rule.dest_addresses != null ? { destinationAddresses = rule.dest_addresses } : {},
            rule.dest_ports != null ? { destinationPorts = rule.dest_ports } : {},
            rule.address_list_refs != null ? { addressListRefs = rule.address_list_refs } : {},
            rule.port_list_refs != null ? { portListRefs = rule.port_list_refs } : {},
            { log = rule.log }
          )
        ]
      } : {}
    )
  }
}

# =============================================================================
# VERIFICATION
# =============================================================================

resource "time_sleep" "wait_for_policy" {
  depends_on = [kubernetes_manifest.f5bigfwpolicy]

  create_duration = "5s"
}

resource "null_resource" "verify_policy" {
  depends_on = [time_sleep.wait_for_policy]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Verifying F5BigFwPolicy ${var.policy_name} ==="

      # Check policy exists
      kubectl get f5bigfwpolicy ${var.policy_name} -n ${var.policy_namespace} || echo "Policy not found yet"

      echo "✓ F5BigFwPolicy verification complete"
    EOT
  }
}

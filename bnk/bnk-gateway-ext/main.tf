# bnk-forge-modules/bnk/bnk-gateway-ext/main.tf
# F5BnkGateway - IPAM Integration for Gateway API (F5 BNK 2.2 GA)

# =============================================================================
# LOCAL VARIABLES
# =============================================================================

locals {
  has_ipv4        = var.ipv4_cidr_range != ""
  has_ipv6        = var.ipv6_cidr_range != ""
  has_any_network = local.has_ipv4 || local.has_ipv6

  networks = concat(
    local.has_ipv4 ? [{
      name = var.default_network
      cidr = var.ipv4_cidr_range
    }] : [],
    local.has_ipv6 ? [{
      name = "${var.default_network}-v6"
      cidr = var.ipv6_cidr_range
    }] : []
  )
}

# =============================================================================
# F5 BNK GATEWAY (IPAM)
# =============================================================================

resource "kubernetes_manifest" "f5_bnk_gateway" {
  count      = local.has_any_network ? 1 : 0
  depends_on = [var.flo_ready]

  manifest = {
    apiVersion = "k8s.f5net.com/v1"
    kind       = "F5BnkGateway"

    metadata = {
      name      = var.gateway_ext_name
      namespace = var.namespace

      labels = merge(var.common_labels, {
        "app.kubernetes.io/name"       = var.gateway_ext_name
        "app.kubernetes.io/component"  = "ipam-gateway"
        "app.kubernetes.io/managed-by" = "terraform"
      })

      annotations = var.annotations
    }

    spec = {
      networks = local.networks
    }
  }
}

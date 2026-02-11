# k8s/network-setup/main.tf
# Network Attachment Definitions for BNK TMM
#
# Creates Multus NetworkAttachmentDefinition CRs for external and internal
# networks. TMM pods use these for dedicated SR-IOV / VF data-plane interfaces.
#
# Key design decisions:
# - No hardcoded PCI bus IDs (they vary per node/cloud)
# - CNI type is configurable (host-device, sriov, vfio)
# - Resource names are configurable (intel.com/xxx, etc.)
# - NADs go in the CNEInstance namespace (f5-operator) since FLO deploys TMM there

# =============================================================================
# EXTERNAL NETWORK ATTACHMENT DEFINITION
# =============================================================================

resource "kubernetes_manifest" "external_nad" {
  manifest = {
    apiVersion = "k8s.cni.cncf.io/v1"
    kind       = "NetworkAttachmentDefinition"
    metadata = {
      name      = "external-netdevice"
      namespace = var.namespace
      annotations = {
        "k8s.v1.cni.cncf.io/resourceName" = var.external_resource_name
      }
    }
    spec = {
      config = jsonencode({
        type       = var.cni_type
        cniVersion = "0.3.1"
        name       = "external-network"
        ipam = {
          type   = "host-local"
          ranges = [for cidr in var.external_subnet_cidrs : [{ subnet = cidr }]]
        }
      })
    }
  }

  field_manager {
    name            = "terraform"
    force_conflicts = true
  }
}

# =============================================================================
# INTERNAL NETWORK ATTACHMENT DEFINITION
# =============================================================================

resource "kubernetes_manifest" "internal_nad" {
  manifest = {
    apiVersion = "k8s.cni.cncf.io/v1"
    kind       = "NetworkAttachmentDefinition"
    metadata = {
      name      = "internal-netdevice"
      namespace = var.namespace
      annotations = {
        "k8s.v1.cni.cncf.io/resourceName" = var.internal_resource_name
      }
    }
    spec = {
      config = jsonencode({
        type       = var.cni_type
        cniVersion = "0.3.1"
        name       = "internal-network"
        ipam = {
          type   = "host-local"
          ranges = [for cidr in var.internal_subnet_cidrs : [{ subnet = cidr }]]
        }
      })
    }
  }

  field_manager {
    name            = "terraform"
    force_conflicts = true
  }
}

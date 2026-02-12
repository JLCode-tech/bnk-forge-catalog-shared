# k8s/network-setup/main.tf
# Network Attachment Definitions for BNK TMM
#
# Creates Multus NetworkAttachmentDefinition CRs for external and internal
# networks. TMM pods use these for dedicated SR-IOV / VF data-plane interfaces.
#
# Key design decisions:
# - No hardcoded PCI bus IDs (they vary per node/cloud)
# - CNI type is configurable (host-device for AWS SR-IOV, sf for DPU, sriov, vfio)
# - Resource names are configurable (intel.com/xxx, nvidia.com/xxx, etc.)
# - NADs go in the CNEInstance namespace (f5-operator) since FLO deploys TMM there
# - NO IPAM — the NAD provides a raw L2 interface only
#   Self-IP configuration is handled by F5SPKVlan CRs (bnk-vlans module)
#   This matches F5 docs, Lanner PoC, and bnk-poc reference implementations

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
      })
    }
  }

  field_manager {
    name            = "terraform"
    force_conflicts = true
  }
}

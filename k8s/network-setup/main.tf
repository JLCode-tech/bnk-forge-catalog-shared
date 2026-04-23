# k8s/network-setup/main.tf
# Network Attachment Definitions for BNK TMM
#
# Default mode (kernel): host-device CNI + pciBusID. The CNI moves the ENI's
# kernel netdev (e.g. eth1, ens7) from the host into the TMM pod's netns.
# TMM runs with TMM_GENERIC_SOCKET_DRIVER=true and uses the kernel network
# stack via raw sockets. Validated on AWS per F5 Doc 3 (Multi-AZ Network
# Architecture) and aws-syd-test.
#
# Legacy mode (sriov): SR-IOV resourceName annotation so the SR-IOV device
# plugin allocates a VFIO-bound VF. Requires the SR-IOV stack from the
# high-performance-nodes module (sriov-cni-installer DS, sriov-device-plugin
# DS, dpdk-configurator DS, sriovdp-config CM, vfio-pci binding in userdata).
#
# Either mode produces NADs named external-netdevice / internal-netdevice in
# var.namespace. CNEInstance.networkAttachments references them by name.
#
# NO IPAM in either mode — the NAD provides a raw L2 interface only. Self-IPs
# are assigned by F5SPKVlan CRs (bnk-vlans module) plus the controller's
# AssignPrivateIpAddresses call against the underlying ENI (Doc 3 page 30,
# requires IRSA + allow-ec2-vip IAM policy).

locals {
  is_kernel_mode = var.tmm_data_plane_mode == "kernel"

  external_config = local.is_kernel_mode ? {
    type       = "host-device"
    cniVersion = "0.3.1"
    name       = "external-network"
    pciBusID   = var.external_pci_bus_id
    } : {
    type       = var.cni_type
    cniVersion = "0.3.1"
    name       = "external-network"
  }

  internal_config = local.is_kernel_mode ? {
    type       = "host-device"
    cniVersion = "0.3.1"
    name       = "internal-network"
    pciBusID   = var.internal_pci_bus_id
    } : {
    type       = var.cni_type
    cniVersion = "0.3.1"
    name       = "internal-network"
  }

  # SR-IOV resource annotations only in sriov mode. In kernel mode the NAD
  # must NOT carry resourceName, otherwise the operator infers the pod needs
  # an intel.com/*_netdevice resource request and TMM stays Pending.
  external_annotations = local.is_kernel_mode ? {} : {
    "k8s.v1.cni.cncf.io/resourceName" = var.external_resource_name
  }

  internal_annotations = local.is_kernel_mode ? {} : {
    "k8s.v1.cni.cncf.io/resourceName" = var.internal_resource_name
  }
}

# =============================================================================
# EXTERNAL NETWORK ATTACHMENT DEFINITION
# =============================================================================

resource "kubernetes_manifest" "external_nad" {
  manifest = {
    apiVersion = "k8s.cni.cncf.io/v1"
    kind       = "NetworkAttachmentDefinition"
    metadata = {
      name        = "external-netdevice"
      namespace   = var.namespace
      annotations = local.external_annotations
    }
    spec = {
      config = jsonencode(local.external_config)
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
      name        = "internal-netdevice"
      namespace   = var.namespace
      annotations = local.internal_annotations
    }
    spec = {
      config = jsonencode(local.internal_config)
    }
  }

  field_manager {
    name            = "terraform"
    force_conflicts = true
  }
}

# =============================================================================
# install-spkvlan-gatewayclass
# =============================================================================
# Cloud-agnostic primitive: apply F5SPKVlan + GatewayClass custom resources
# for the BNK host-device data-plane pattern.
#
# F5SPKVlan plumbs the external (and optionally internal) TMM trunks to named
# VLANs inside the TMM pod netns, announcing the SelfIPs that were
# pre-assigned as secondary IPs on the host interfaces (ENIs on AWS, equivalent
# on other clouds). Without this, even a Programmed CNEInstance cannot pass
# traffic — TMM knows its interfaces but has no VLAN → SelfIP binding.
#
# GatewayClass registers the BNK cne-controller as a Gateway API implementation.
# Operator-facing Gateway CRs reference this class via .spec.gatewayClassName.
#
# Source (CR shapes):
#   F5SPKVlan: awsbnkctl:internal/k8s/manifests/host-device/f5spkvlan.yaml.tmpl
#   GatewayClass: awsbnkctl:internal/k8s/manifests/host-device/gatewayclass.yaml.tmpl
#   Render logic: awsbnkctl:internal/k8s/render/render.go (RenderF5SPKVlan, RenderGatewayClass)
#   Apply phase: awsbnkctl:internal/aws/phases/phase23b_spkvlan_gatewayclass.go
#
# Deploy order (per awsbnkctl Phase 23b):
#   AFTER: cneinstall, License CR (phase 23) — FLO installs F5SPKVlan + GatewayClass
#          CRDs only once CNEInstance reaches Reconciled
#   BEFORE: CWC heal (phase 24), any operator-facing Gateway CRs
#
# IMPORTANT: The F5SPKVlan CRD (f5-spk-vlans.k8s.f5net.com) and GatewayClass
# CRD (gatewayclasses.gateway.networking.k8s.io) are installed by FLO's
# crd-installer Job AFTER the CNEInstance reaches Reconciled. This module
# waits for both CRDs before applying either CR.
#
# Interface inputs: the SelfIP addresses and prefix length are cloud-specific
# (e.g. discovered from AWS ENI secondary IPs in phase 17). The per-cloud
# caller (aws-eks wrapper module) supplies them. They must NOT be hardcoded here.

resource "local_sensitive_file" "kubeconfig" {
  filename        = "${path.module}/work/kubeconfig"
  file_permission = "0600"
  content         = try(local.forge_kubeconfig, var.forge_kubeconfig_content)
}

locals {
  kubectl = "kubectl --kubeconfig ${local_sensitive_file.kubeconfig.filename}"

  # Render F5SPKVlan ext-vlan manifest
  f5spkvlan_ext_manifest = templatefile("${path.module}/manifests/f5spkvlan-ext.yaml.tpl", {
    instance_namespace   = var.instance_namespace
    tmm_ext_selfip       = var.tmm_ext_selfip
    tmm_selfip_prefixlen = var.tmm_selfip_prefixlen
  })

  # Render F5SPKVlan int-vlan manifest (dual-interface only)
  f5spkvlan_int_manifest = var.has_internal_interface ? templatefile("${path.module}/manifests/f5spkvlan-int.yaml.tpl", {
    instance_namespace   = var.instance_namespace
    tmm_int_selfip       = var.tmm_int_selfip
    tmm_selfip_prefixlen = var.tmm_selfip_prefixlen
  }) : ""

  # Render GatewayClass manifest
  gatewayclass_manifest = templatefile("${path.module}/manifests/gatewayclass.yaml.tpl", {
    gatewayclass_name  = var.gatewayclass_name != "" ? var.gatewayclass_name : "${var.cluster_name}-gatewayclass"
    cluster_name       = var.cluster_name
    instance_namespace = var.instance_namespace
  })

  gatewayclass_name_resolved = var.gatewayclass_name != "" ? var.gatewayclass_name : "${var.cluster_name}-gatewayclass"
}

# Write rendered manifests to work/ so they can be applied and referenced
# in destroy provisioners.

resource "local_file" "f5spkvlan_ext" {
  filename = "${path.module}/work/f5spkvlan-ext.yaml"
  content  = local.f5spkvlan_ext_manifest
}

resource "local_file" "f5spkvlan_int" {
  count    = var.has_internal_interface ? 1 : 0
  filename = "${path.module}/work/f5spkvlan-int.yaml"
  content  = local.f5spkvlan_int_manifest
}

resource "local_file" "gatewayclass" {
  filename = "${path.module}/work/gatewayclass.yaml"
  content  = local.gatewayclass_manifest
}

# Wait for F5SPKVlan CRD then apply ext-vlan (and int-vlan if dual-interface).
resource "null_resource" "spkvlan_apply" {
  triggers = {
    ext_manifest    = local.f5spkvlan_ext_manifest
    int_manifest    = local.f5spkvlan_int_manifest
    kubeconfig_file = local_sensitive_file.kubeconfig.filename
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      echo "[install-spkvlan-gatewayclass] waiting for F5SPKVlan CRD (up to ${var.crd_wait_timeout})"
      ${local.kubectl} wait --for=condition=Established \
        --timeout=${var.crd_wait_timeout} \
        crd/f5-spk-vlans.k8s.f5net.com

      echo "[install-spkvlan-gatewayclass] applying F5SPKVlan ext-vlan"
      ${local.kubectl} apply -f "${path.module}/work/f5spkvlan-ext.yaml"

      %{if var.has_internal_interface}
      echo "[install-spkvlan-gatewayclass] applying F5SPKVlan int-vlan"
      ${local.kubectl} apply -f "${path.module}/work/f5spkvlan-int.yaml"
      %{endif}

      echo "[install-spkvlan-gatewayclass] F5SPKVlan applied"
    EOT
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["bash", "-c"]
    on_failure  = continue
    command     = <<-EOT
      echo "[install-spkvlan-gatewayclass] deleting F5SPKVlan ext-vlan + int-vlan"
      kubectl --kubeconfig "${self.triggers.kubeconfig_file}" \
        delete f5-spk-vlan ext-vlan int-vlan \
        -n ${var.instance_namespace} \
        --ignore-not-found || true
    EOT
  }

  depends_on = [
    local_file.f5spkvlan_ext,
    local_file.f5spkvlan_int,
  ]
}

# Wait for GatewayClass CRD then apply GatewayClass.
# Per awsbnkctl phase23b: wait for BOTH CRDs before applying EITHER CR
# (GatewayClass apply races the RESTMapper cache when CRD landed <2s earlier).
resource "null_resource" "gatewayclass_apply" {
  triggers = {
    gatewayclass_manifest = local.gatewayclass_manifest
    kubeconfig_file       = local_sensitive_file.kubeconfig.filename
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      echo "[install-spkvlan-gatewayclass] waiting for GatewayClass CRD (up to ${var.crd_wait_timeout})"
      ${local.kubectl} wait --for=condition=Established \
        --timeout=${var.crd_wait_timeout} \
        crd/gatewayclasses.gateway.networking.k8s.io

      echo "[install-spkvlan-gatewayclass] applying GatewayClass ${local.gatewayclass_name_resolved}"
      ${local.kubectl} apply -f "${path.module}/work/gatewayclass.yaml"

      echo "[install-spkvlan-gatewayclass] GatewayClass applied"
    EOT
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["bash", "-c"]
    on_failure  = continue
    command     = <<-EOT
      echo "[install-spkvlan-gatewayclass] deleting GatewayClass ${local.gatewayclass_name_resolved}"
      kubectl --kubeconfig "${self.triggers.kubeconfig_file}" \
        delete gatewayclass "${local.gatewayclass_name_resolved}" \
        --ignore-not-found || true
    EOT
  }

  depends_on = [
    local_file.gatewayclass,
    null_resource.spkvlan_apply,
  ]
}

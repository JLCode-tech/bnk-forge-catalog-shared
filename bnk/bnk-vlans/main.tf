# bnk/bnk-vlans/main.tf
# F5SPKVlan CRs — TMM VLAN Self IPs
#
# Creates F5SPKVlan custom resources that tell TMM which IP addresses to use
# on its data-plane interfaces. TMM configures these IPs on its interfaces
# itself — they are NOT assigned by Multus IPAM (the NADs have no IPAM).
#
# Reference: https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/bnk-configure-network.html
#
# Uses kubectl apply because the F5SPKVlan CRD is installed by FLO at runtime,
# not available at plan time (same pattern as cneinstance module).
#
# Interface mapping (determined by order in CNEInstance networkAttachments):
#   1.1 = external (first NAD listed = external-netdevice)
#   1.2 = internal (second NAD listed = internal-netdevice)

# =============================================================================
# KUBECONFIG FOR KUBECTL
# =============================================================================

resource "local_file" "kubeconfig" {
  filename        = "${path.module}/work/kubeconfig"
  file_permission = "0600"
  content = yamlencode({
    apiVersion = "v1"
    kind       = "Config"
    clusters = [{
      name = "cluster"
      cluster = {
        server                     = data.aws_eks_cluster.cluster.endpoint
        certificate-authority-data = data.aws_eks_cluster.cluster.certificate_authority[0].data
      }
    }]
    users = [{
      name = "user"
      user = {
        token = data.aws_eks_cluster_auth.cluster.token
      }
    }]
    contexts = [{
      name = "default"
      context = {
        cluster = "cluster"
        user    = "user"
      }
    }]
    current-context = "default"
  })
}

# =============================================================================
# LOCAL VALUES
# =============================================================================

locals {
  kubectl = "kubectl --kubeconfig ${local_file.kubeconfig.filename}"

  # Prefix length from subnet CIDR (e.g. "10.0.10.0/24" → 24)
  external_prefixlen = tonumber(split("/", var.external_subnet_cidrs[0])[1])
  internal_prefixlen = tonumber(split("/", var.internal_subnet_cidrs[0])[1])
}

# =============================================================================
# WRITE VLAN MANIFESTS
# =============================================================================

resource "local_file" "vlan_manifests" {
  filename = "${path.module}/work/vlans.yaml"
  content  = <<-YAML
apiVersion: k8s.f5net.com/v1
kind: F5SPKVlan
metadata:
  name: external
  namespace: ${var.namespace}
spec:
  name: external
  interfaces:
  - "1.1"
  mtu: ${var.mtu}
  selfip_v4s:
%{for ip in var.external_self_ips~}
  - ${ip}
%{endfor~}
  prefixlen_v4: ${local.external_prefixlen}
---
apiVersion: k8s.f5net.com/v1
kind: F5SPKVlan
metadata:
  name: internal
  namespace: ${var.namespace}
spec:
  name: internal
  internal: true
  interfaces:
  - "1.2"
  mtu: ${var.mtu}
  selfip_v4s:
%{for ip in var.internal_self_ips~}
  - ${ip}
%{endfor~}
  prefixlen_v4: ${local.internal_prefixlen}
YAML
}

# =============================================================================
# APPLY VLAN CRs
# =============================================================================

resource "null_resource" "vlans" {
  triggers = {
    manifest_hash = sha256(local_file.vlan_manifests.content)
    namespace     = var.namespace
    kubeconfig    = local_file.kubeconfig.filename
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Applying F5SPKVlan CRs ==="

      # Wait for the F5SPKVlan CRD to exist (FLO installs it)
      TIMEOUT=120
      ELAPSED=0
      while [ $ELAPSED -lt $TIMEOUT ]; do
        ${local.kubectl} get crd f5-spk-vlans.k8s.f5net.com >/dev/null 2>&1 && break
        echo "  Waiting for F5SPKVlan CRD ($${ELAPSED}s)..."
        sleep 10
        ELAPSED=$((ELAPSED + 10))
      done

      if ! ${local.kubectl} get crd f5-spk-vlans.k8s.f5net.com >/dev/null 2>&1; then
        echo "ERROR: F5SPKVlan CRD not found after $${TIMEOUT}s — is FLO deployed?"
        exit 1
      fi

      ${local.kubectl} apply -f ${local_file.vlan_manifests.filename} 2>&1

      if [ $? -ne 0 ]; then
        echo "ERROR: Failed to apply VLAN manifests"
        exit 1
      fi

      echo ""
      echo "=== VLAN CRs applied ==="
      ${local.kubectl} get f5-spk-vlans.k8s.f5net.com -n ${var.namespace} 2>/dev/null
    EOT
  }

  # Destroy: delete the VLAN CRs
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "=== Deleting F5SPKVlan CRs ==="
      kubectl --kubeconfig ${self.triggers.kubeconfig} delete f5spkvlan external internal \
        -n ${self.triggers.namespace} \
        --timeout=60s 2>/dev/null || \
      echo "VLAN CRs already deleted or not found"
    EOT
  }

  depends_on = [local_file.vlan_manifests]
}

# =============================================================================
# WAIT FOR VLANS TO BE PROGRAMMED
# =============================================================================

resource "null_resource" "wait_for_programmed" {
  depends_on = [null_resource.vlans]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Waiting for VLAN CRs to be Programmed ==="

      TIMEOUT=180
      INTERVAL=10
      ELAPSED=0

      while [ $ELAPSED -lt $TIMEOUT ]; do
        EXT_STATUS=$(${local.kubectl} get f5-spk-vlans.k8s.f5net.com external \
          -n ${var.namespace} \
          -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null)
        INT_STATUS=$(${local.kubectl} get f5-spk-vlans.k8s.f5net.com internal \
          -n ${var.namespace} \
          -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}' 2>/dev/null)

        if [ "$EXT_STATUS" = "True" ] && [ "$INT_STATUS" = "True" ]; then
          echo "Both VLANs are Programmed!"
          break
        fi

        echo "  external=$EXT_STATUS internal=$INT_STATUS ($${ELAPSED}s)"
        sleep $INTERVAL
        ELAPSED=$((ELAPSED + INTERVAL))
      done

      if [ "$EXT_STATUS" != "True" ] || [ "$INT_STATUS" != "True" ]; then
        echo ""
        echo "WARNING: VLANs not yet Programmed after $${TIMEOUT}s"
        echo "This may resolve once TMM readiness gates go True."
        echo "Current status:"
        ${local.kubectl} get f5-spk-vlans.k8s.f5net.com -n ${var.namespace} -o yaml 2>/dev/null | grep -A5 "Programmed" || true
      fi
    EOT
  }
}

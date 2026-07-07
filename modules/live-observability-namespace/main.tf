# =============================================================================
# live-observability-namespace
# =============================================================================
# Cloud-agnostic primitive: create and label the Kubernetes namespace that
# hosts all BNK live observability components (Loki log store + Fluent Bit
# collector DaemonSet).
#
# Default namespace: llm-egress
# This matches the Forge AI Gateway observability_namespace setting in PR #393.
# Override only if your cluster already uses a different convention.
#
# Sequence:
#   1. kubectl create namespace (--dry-run=client -o yaml | kubectl apply -f -)
#      so the apply is idempotent even if the namespace already exists.
#   2. kubectl label the namespace with standard BNK Forge labels.
#   3. kubectl wait until the namespace phase is Active.

resource "local_sensitive_file" "kubeconfig" {
  filename        = "${path.module}/work/kubeconfig"
  file_permission = "0600"
  content         = try(local.forge_kubeconfig, var.forge_kubeconfig_content)
}

locals {
  kubectl = "kubectl --kubeconfig ${local_sensitive_file.kubeconfig.filename}"
}

resource "null_resource" "namespace" {
  triggers = {
    namespace      = var.observability_namespace
    poc_label      = var.poc_label
    kubeconfig_sha = sha256(try(local.forge_kubeconfig, var.forge_kubeconfig_content))
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      echo "[live-observability-namespace] creating namespace ${var.observability_namespace}"
      ${local.kubectl} create namespace "${var.observability_namespace}" \
        --dry-run=client -o yaml | ${local.kubectl} apply -f -

      echo "[live-observability-namespace] labelling namespace"
      ${local.kubectl} label namespace "${var.observability_namespace}" \
        app.kubernetes.io/managed-by=bnk-forge \
        app.kubernetes.io/part-of=bnk-live-observability \
        bnk-forge/poc="${var.poc_label}" \
        --overwrite

      echo "[live-observability-namespace] waiting for namespace to be Active"
      ${local.kubectl} wait namespace "${var.observability_namespace}" \
        --for=jsonpath='{.status.phase}'=Active \
        --timeout=60s

      echo "[live-observability-namespace] complete"
    EOT
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["bash", "-c"]
    on_failure  = continue
    command     = <<-EOT
      echo "[live-observability-namespace] deleting namespace ${self.triggers.namespace}"
      kubectl --kubeconfig "${self.triggers.kubeconfig_sha}" delete namespace \
        "${self.triggers.namespace}" --ignore-not-found || true
    EOT
  }
}

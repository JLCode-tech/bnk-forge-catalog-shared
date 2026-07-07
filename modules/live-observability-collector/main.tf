# =============================================================================
# live-observability-collector
# =============================================================================
# Cloud-agnostic primitive: deploy a Fluent Bit DaemonSet that tails all pod
# logs in the cluster, parses JSON records, promotes selected JSON fields to
# Loki stream labels, and forwards matching records to the Loki push API.
#
# This is real live log collection — NOT a data generator. Fluent Bit only
# forwards logs that pods actually emit. Traffic-producing blueprints (e.g. an
# AI Gateway PoC) must emit real structured JSON logs for data to appear in
# Loki.
#
# Label promotion:
#   Fluent Bit's Lua filter extracts job, model, and status from the parsed
#   JSON payload and sets them as Fluent Bit record fields. The Loki output
#   plugin then promotes those fields to Loki stream labels, enabling
#   label-indexed LogQL queries:
#     {job="llm-gateway", model="gpt-4o", status="2xx"}
#
# Producer requirement:
#   Every traffic-producing blueprint MUST emit JSON log lines with at minimum:
#     {"job":"llm-gateway","model":"<name>","status":"<2xx|4xx|5xx>", ...}
#   See modules/live-observability-loki/README.md for the full field contract.
#
# Sequence:
#   1. Write Fluent Bit ConfigMap from template (loki_host, loki_port, and
#      namespace interpolated at apply time via local_file + kubectl apply).
#   2. kubectl apply RBAC (ServiceAccount, ClusterRole, ClusterRoleBinding).
#   3. kubectl apply DaemonSet.
#   4. kubectl rollout status waits for the DaemonSet to be Ready.
#
# Destroy:
#   kubectl delete the DaemonSet and RBAC resources with --ignore-not-found.

resource "local_sensitive_file" "kubeconfig" {
  filename        = "${path.module}/work/kubeconfig"
  file_permission = "0600"
  content         = try(local.forge_kubeconfig, var.forge_kubeconfig_content)
}

locals {
  kubectl = "kubectl --kubeconfig ${local_sensitive_file.kubeconfig.filename}"
  ns      = var.observability_namespace

  # In-cluster DNS hostname for Loki. The Fluent Bit Loki output plugin
  # expects Host/Port/URI separately, not a full URL in Host.
  loki_host = "${var.loki_service_name}.${var.observability_namespace}.svc.cluster.local"
}

# ---------------------------------------------------------------------------
# Fluent Bit ConfigMap (rendered with loki_host, loki_port, namespace)
# ---------------------------------------------------------------------------

resource "local_file" "fluent_bit_configmap" {
  count    = var.enable_pod_log_collection ? 1 : 0
  filename = "${path.module}/work/fluent-bit-configmap.yaml"
  content = templatefile("${path.module}/manifests/fluent-bit-configmap.yaml.tpl", {
    observability_namespace = var.observability_namespace
    loki_host               = local.loki_host
    loki_port               = var.loki_port
  })
}

resource "local_file" "fluent_bit_daemonset" {
  count    = var.enable_pod_log_collection ? 1 : 0
  filename = "${path.module}/work/fluent-bit-daemonset.yaml"
  content = templatefile("${path.module}/manifests/fluent-bit-daemonset.yaml.tpl", {
    observability_namespace = var.observability_namespace
    fluent_bit_version      = var.fluent_bit_version
  })
}

resource "null_resource" "collector_rbac" {
  count = var.enable_pod_log_collection ? 1 : 0

  triggers = {
    namespace       = var.observability_namespace
    manifest        = filemd5("${path.module}/manifests/fluent-bit-rbac.yaml")
    kubeconfig_file = local_sensitive_file.kubeconfig.filename
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      echo "[live-observability-collector] applying Fluent Bit RBAC in ${local.ns}"
      sed 's/__NAMESPACE__/${var.observability_namespace}/g' \
        "${path.module}/manifests/fluent-bit-rbac.yaml" | \
        ${local.kubectl} apply -f -
      echo "[live-observability-collector] RBAC applied"
    EOT
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["bash", "-c"]
    on_failure  = continue
    command     = <<-EOT
      echo "[live-observability-collector] removing Fluent Bit RBAC"
      sed 's/__NAMESPACE__/${self.triggers.namespace}/g' \
        "${path.module}/manifests/fluent-bit-rbac.yaml" | \
        kubectl --kubeconfig "${self.triggers.kubeconfig_file}" delete -f - --ignore-not-found || true
    EOT
  }

  depends_on = [local_sensitive_file.kubeconfig]
}

resource "null_resource" "collector_install" {
  count = var.enable_pod_log_collection ? 1 : 0

  triggers = {
    configmap_sha   = sha256(local_file.fluent_bit_configmap[0].content)
    daemonset_sha   = sha256(local_file.fluent_bit_daemonset[0].content)
    loki_host       = local.loki_host
    loki_port       = tostring(var.loki_port)
    namespace       = var.observability_namespace
    kubeconfig_file = local_sensitive_file.kubeconfig.filename
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      echo "[live-observability-collector] applying Fluent Bit ConfigMap"
      ${local.kubectl} apply -f "${local_file.fluent_bit_configmap[0].filename}"

      echo "[live-observability-collector] applying Fluent Bit DaemonSet"
      ${local.kubectl} apply -f "${local_file.fluent_bit_daemonset[0].filename}"

      echo "[live-observability-collector] waiting for Fluent Bit DaemonSet rollout"
      ${local.kubectl} -n "${var.observability_namespace}" rollout status \
        ds/fluent-bit \
        --timeout=180s

      echo "[live-observability-collector] complete"
    EOT
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["bash", "-c"]
    on_failure  = continue
    command     = <<-EOT
      echo "[live-observability-collector] removing Fluent Bit DaemonSet and ConfigMap"
      kubectl --kubeconfig "${self.triggers.kubeconfig_file}" \
        -n "${self.triggers.namespace}" delete ds/fluent-bit --ignore-not-found || true
      kubectl --kubeconfig "${self.triggers.kubeconfig_file}" \
        -n "${self.triggers.namespace}" delete configmap/fluent-bit-config --ignore-not-found || true
    EOT
  }

  depends_on = [
    null_resource.collector_rbac,
    local_file.fluent_bit_configmap,
    local_file.fluent_bit_daemonset,
  ]
}

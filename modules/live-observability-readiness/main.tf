# =============================================================================
# live-observability-readiness
# =============================================================================
# Cloud-agnostic gate: verify that Loki is responding to /ready via the
# Kubernetes API-server service proxy path before marking the observability
# stack as available.
#
# Probe path:
#   kubectl get --raw \
#     /api/v1/namespaces/<ns>/services/http:<svc>:<port>/proxy/ready
#
# This path goes through the K8s API server in-cluster without requiring
# external network access to the Loki Service from the Forge runner. It works
# in private clusters and air-gapped environments as long as the runner can
# reach the API server.
#
# The probe retries until success or timeout. Exit code 0 = Loki is ready.
# The null_resource will fail the apply if Loki does not become ready within
# readiness_timeout_seconds.
#
# Destroy:
#   No-op — this module creates no persistent Kubernetes resources.

resource "local_sensitive_file" "kubeconfig" {
  filename        = "${path.module}/work/kubeconfig"
  file_permission = "0600"
  content         = try(local.forge_kubeconfig, var.forge_kubeconfig_content)
}

locals {
  kubectl    = "kubectl --kubeconfig ${local_sensitive_file.kubeconfig.filename}"
  proxy_path = "/api/v1/namespaces/${var.observability_namespace}/services/http:${var.loki_service_name}:${var.loki_port}/proxy/ready"
}

resource "null_resource" "loki_readiness" {
  triggers = {
    namespace         = var.observability_namespace
    loki_service_name = var.loki_service_name
    loki_port         = tostring(var.loki_port)
    timeout           = tostring(var.readiness_timeout_seconds)
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      PROXY_PATH="${local.proxy_path}"
      TIMEOUT="${var.readiness_timeout_seconds}"
      ELAPSED=0
      INTERVAL=5

      echo "[live-observability-readiness] polling Loki /ready via API proxy: $PROXY_PATH"
      echo "[live-observability-readiness] timeout: $${TIMEOUT}s"

      until ${local.kubectl} get --raw "$PROXY_PATH" 2>/dev/null | grep -q "ready"; do
        if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
          echo "[live-observability-readiness] TIMEOUT after $${ELAPSED}s — Loki not ready"
          echo "[live-observability-readiness] last response:"
          ${local.kubectl} get --raw "$PROXY_PATH" 2>&1 || true
          exit 1
        fi
        echo "[live-observability-readiness] not ready yet (elapsed $${ELAPSED}s), retrying in $${INTERVAL}s..."
        sleep "$INTERVAL"
        ELAPSED=$((ELAPSED + INTERVAL))
      done

      echo "[live-observability-readiness] Loki is ready (elapsed $${ELAPSED}s)"
    EOT
  }
}

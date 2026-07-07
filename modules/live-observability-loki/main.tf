# =============================================================================
# live-observability-loki
# =============================================================================
# Cloud-agnostic primitive: deploy Grafana Loki as plain Kubernetes manifests
# using kubectl. No Helm. Single-replica, emptyDir storage for PoC retention.
# Service name and port match Forge AI Gateway defaults (loki:3100).
#
# Sequence:
#   1. Write kubeconfig to disk (Forge injects via local.forge_kubeconfig).
#   2. Render manifest templates (ConfigMap, Deployment, Service) with variable
#      substitution and write them to the work/ directory.
#   3. kubectl apply -f in numbered order.
#   4. kubectl rollout status waits for the Deployment to be Ready.
#
# Destroy:
#   kubectl delete all rendered manifests with --ignore-not-found.
#
# Outputs:
#   loki_endpoint     — in-cluster push URL for Fluent Bit / direct producers
#   loki_service_name — resolved service name (passes through for consumers)
#   loki_ready        — gate: true once manifests are applied and rollout done

resource "local_sensitive_file" "kubeconfig" {
  filename        = "${path.module}/work/kubeconfig"
  file_permission = "0600"
  content         = try(local.forge_kubeconfig, var.forge_kubeconfig_content)
}

locals {
  kubectl = "kubectl --kubeconfig ${local_sensitive_file.kubeconfig.filename}"
  ns      = var.observability_namespace

  # Computed output values
  loki_endpoint = "http://${var.loki_service_name}.${var.observability_namespace}.svc.cluster.local:${var.loki_port}/loki/api/v1/push"
}

# ---------------------------------------------------------------------------
# Rendered manifest files
# ---------------------------------------------------------------------------

resource "local_file" "loki_config" {
  filename = "${path.module}/work/01-loki-config.yaml"
  content = templatefile("${path.module}/manifests/01-loki-config.yaml", {
    observability_namespace = var.observability_namespace
    loki_port               = var.loki_port
    loki_retention_hours    = var.loki_retention_hours
  })
}

resource "local_file" "loki_deployment" {
  filename = "${path.module}/work/02-loki-deployment.yaml"
  content = templatefile("${path.module}/manifests/02-loki-deployment.yaml", {
    observability_namespace = var.observability_namespace
    loki_port               = var.loki_port
  })
}

resource "local_file" "loki_service" {
  filename = "${path.module}/work/03-loki-service.yaml"
  content = templatefile("${path.module}/manifests/03-loki-service.yaml", {
    observability_namespace = var.observability_namespace
    loki_service_name       = var.loki_service_name
    loki_port               = var.loki_port
  })
}

# ---------------------------------------------------------------------------
# Apply manifests
# ---------------------------------------------------------------------------

resource "null_resource" "loki_install" {
  triggers = {
    config_sha      = sha256(local_file.loki_config.content)
    deployment_sha  = sha256(local_file.loki_deployment.content)
    service_sha     = sha256(local_file.loki_service.content)
    namespace       = var.observability_namespace
    service_name    = var.loki_service_name
    port            = tostring(var.loki_port)
    kubeconfig_file = local_sensitive_file.kubeconfig.filename
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      echo "[live-observability-loki] applying Loki ConfigMap"
      ${local.kubectl} apply -f "${local_file.loki_config.filename}"

      echo "[live-observability-loki] applying Loki Deployment"
      ${local.kubectl} apply -f "${local_file.loki_deployment.filename}"

      echo "[live-observability-loki] applying Loki Service"
      ${local.kubectl} apply -f "${local_file.loki_service.filename}"

      echo "[live-observability-loki] waiting for Loki Deployment rollout"
      ${local.kubectl} -n "${local.ns}" rollout status \
        deployment/loki \
        --timeout=180s

      echo "[live-observability-loki] complete"
    EOT
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["bash", "-c"]
    on_failure  = continue
    command     = <<-EOT
      echo "[live-observability-loki] removing Loki resources"
      kubectl --kubeconfig "${self.triggers.kubeconfig_file}" \
        -n "${self.triggers.namespace}" \
        delete deployment/loki --ignore-not-found || true
      kubectl --kubeconfig "${self.triggers.kubeconfig_file}" \
        -n "${self.triggers.namespace}" \
        delete service/"${self.triggers.service_name}" --ignore-not-found || true
      kubectl --kubeconfig "${self.triggers.kubeconfig_file}" \
        -n "${self.triggers.namespace}" \
        delete configmap/loki-config --ignore-not-found || true
    EOT
  }

  depends_on = [
    local_sensitive_file.kubeconfig,
    local_file.loki_config,
    local_file.loki_deployment,
    local_file.loki_service,
  ]
}

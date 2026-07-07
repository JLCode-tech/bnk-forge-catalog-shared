# =============================================================================
# live-observability-cluster-adopt
# =============================================================================
# Cloud-agnostic cluster adoption for the bnk-live-observability-foundation
# blueprint. Accepts a plain-text kubeconfig for any Kubernetes cluster
# (EKS, AKS, GKE, ROKS, on-prem) and validates API server connectivity before
# downstream modules (namespace, loki, collector, readiness) are allowed to run.
#
# Design notes:
#
# 1. Direct-kubeconfig mode — no SSH, no cloud credentials.
#    The kubeconfig_content variable is written to disk at 0600 and never
#    emitted in any non-sensitive output. The downstream modules receive it
#    via the blueprint-level kubeconfig_content input (see forge-blueprint.json
#    wiring: forge_kubeconfig_content = "${kubeconfig_content}").
#
# 2. Forge auto-registration is NOT performed here.
#    Forge's cluster auto-registration contract (cluster_name +
#    remote_kubeconfig_path + remote_host) requires SSH access to a remote host
#    and is only used by the SSH-fetched kubeconfig path. For a directly-provided
#    kubeconfig the cluster row in the Forge DB must be created manually via:
#      Forge UI > Settings > Clusters > Add cluster
#    This is documented in this module's README and in the blueprint README.
#    The Forge PR #393 Loki dashboard uses the cluster DB row to scope queries;
#    skipping registration means the dashboard cluster-selector will not include
#    this cluster until it is registered manually.
#
# 3. work/ directory.
#    The kubeconfig file and extracted API server URL are written to
#    ${path.module}/work/ which is .gitignored. Destroy removes the directory.

resource "local_sensitive_file" "kubeconfig" {
  filename        = "${path.module}/work/kubeconfig"
  file_permission = "0600"
  content         = var.kubeconfig_content
}

locals {
  kubectl = "kubectl --kubeconfig ${local_sensitive_file.kubeconfig.filename}"

  # Extract the cluster server URL from the kubeconfig for the output.
  # Using an external data source keeps the extraction in-process rather than
  # shelling out to yq/python at every plan. Falls back to "<unknown>" if the
  # kubeconfig cannot be parsed — this should never happen for a valid kubeconfig.
  cluster_api_server_cmd = "kubectl --kubeconfig ${local_sensitive_file.kubeconfig.filename} config view --minify --output=jsonpath='{.clusters[0].cluster.server}' 2>/dev/null || echo '<unknown>'"
}

# Extract API server URL (non-sensitive: it's the public endpoint)
resource "null_resource" "extract_api_server" {
  triggers = {
    kubeconfig_hash = sha256(var.kubeconfig_content)
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      mkdir -p "${path.module}/work"
      SERVER=$(kubectl --kubeconfig "${local_sensitive_file.kubeconfig.filename}" \
        config view --minify --output=jsonpath='{.clusters[0].cluster.server}' 2>/dev/null || echo "<unknown>")
      printf '%s' "$SERVER" > "${path.module}/work/api_server.txt"
      echo "[live-observability-cluster-adopt] API server: $SERVER"
    EOT
  }

  depends_on = [local_sensitive_file.kubeconfig]
}

locals {
  # Read the extracted API server URL from the work file.
  # data.local_file reads at plan time; the file may not exist on first plan
  # (before apply), so we guard with a default.
  cluster_api_server = try(
    trimspace(file("${path.module}/work/api_server.txt")),
    "<pending>"
  )
}

# Verify that kubectl can reach the API server before downstream modules run.
resource "null_resource" "verify_connectivity" {
  triggers = {
    cluster_name    = var.cluster_name
    kubeconfig_hash = sha256(var.kubeconfig_content)
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -euo pipefail

      echo "[live-observability-cluster-adopt] validating connectivity to cluster '${var.cluster_name}'"

      if ! ${local.kubectl} cluster-info --request-timeout=15s > /dev/null 2>&1; then
        echo "[live-observability-cluster-adopt] ERROR: cannot reach cluster API server"
        echo "[live-observability-cluster-adopt] check that kubeconfig_content is valid and"
        echo "  the cluster API server is reachable from the Forge runner."
        ${local.kubectl} cluster-info --request-timeout=15s 2>&1 || true
        exit 1
      fi

      echo "[live-observability-cluster-adopt] connectivity verified for '${var.cluster_name}'"
      echo "[live-observability-cluster-adopt] NOTE: this module does NOT auto-register the"
      echo "  cluster in Forge. Register manually via Forge UI > Settings > Clusters"
      echo "  to enable the PR #393 Loki dashboard cluster-selector."
    EOT
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["bash", "-c"]
    on_failure  = continue
    command     = <<-EOT
      echo "[live-observability-cluster-adopt] cleanup: removing work directory"
      rm -rf "${path.module}/work" || true
    EOT
  }

  depends_on = [
    local_sensitive_file.kubeconfig,
    null_resource.extract_api_server,
  ]
}

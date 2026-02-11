# k8s/bnk-prerequisites/main.tf
# BNK Prerequisites — Namespaces + FAR Secrets + Manifest Download
#
# This module is the FIRST module in the BNK stack. It:
# 1. Creates required namespaces (f5-operator, f5-utils, gateway-ns)
# 2. Creates FAR image pull secrets from cne_pull_secret (project secret)
# 3. Downloads BNK manifest from repo.f5.com
# 4. Parses component versions (FLO version, cert-manager version, etc.)
#
# The cne_pull_secret is the base64-encoded JSON service account key from F5.
# It is injected as a project secret (highest priority in variable resolution).

# =============================================================================
# KUBECONFIG FOR KUBECTL (used by destroy-time cleanup)
# =============================================================================
# NOTE: data.aws_eks_cluster.cluster and data.aws_eks_cluster_auth.cluster
# are provided by BNK-Forge platform auto-injection (bnk_forge_providers.tf).
# Do NOT declare them here — that causes duplicate resource errors.

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
# LOCALS
# =============================================================================

locals {
  kubectl = "kubectl --kubeconfig ${local_file.kubeconfig.filename}"
  # Docker auth for FAR: _json_key_base64:<base64 key content>
  docker_auth = base64encode("_json_key_base64:${var.cne_pull_secret}")

  # Docker config JSON for all pull secrets
  docker_config_json = jsonencode({
    auths = {
      "repo.f5.com" = {
        auth = local.docker_auth
      }
    }
  })

}

# =============================================================================
# DESTROY-TIME CLEANUP
# =============================================================================
# BNK installs webhooks and CRD instances with finalizers. On destroy:
# 1. Delete F5 validating/mutating webhooks (they block resource deletion)
# 2. Strip finalizers from all F5 CRD instances (they block namespace deletion)
# 3. Strip finalizers from F5SPKVlan CRs (handletmmconfig_inconsistency)
# 4. Force-finalize namespace if still stuck
#
# Without this, namespace deletion hangs indefinitely because:
# - Webhook f5validate.f5net.com tries to call a service that's already deleted
# - CNEInstance has k8s.f5.com/CNEInstanceFinalizer
# - FLO component CRs have k8s.f5net.com/uninstall finalizer
# - VLAN CRs have handletmmconfig_inconsistency finalizer

resource "null_resource" "bnk_cleanup" {
  triggers = {
    operator_namespace = var.operator_namespace
    utils_namespace    = var.utils_namespace
    kubeconfig         = local_file.kubeconfig.filename
  }

  # Create: no-op
  provisioner "local-exec" {
    command = "echo 'BNK cleanup resource created (runs on destroy only)'"
  }

  # Destroy: clean up webhooks, finalizers, and stuck namespaces
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      KUBECONFIG="${self.triggers.kubeconfig}"
      NS="${self.triggers.operator_namespace}"
      KC="kubectl --kubeconfig $KUBECONFIG"

      echo "=== BNK Pre-Destroy Cleanup ==="

      # Step 1: Delete F5 webhooks
      echo "Step 1: Removing F5 webhooks..."
      for wh in $($KC get validatingwebhookconfiguration -o name 2>/dev/null | grep f5); do
        echo "  Deleting $wh"
        $KC delete $wh --timeout=10s 2>/dev/null || true
      done
      for wh in $($KC get mutatingwebhookconfiguration -o name 2>/dev/null | grep f5); do
        echo "  Deleting $wh"
        $KC delete $wh --timeout=10s 2>/dev/null || true
      done

      # Step 2: Strip finalizers from all F5 CRD instances in namespace
      echo "Step 2: Stripping finalizers from F5 CRD instances..."
      F5_CRDS=$($KC get crd -o name 2>/dev/null | grep -E 'k8s\.f5\.(com|net\.com)' | sed 's|customresourcedefinition.apiextensions.k8s.io/||')
      for crd in $F5_CRDS; do
        RESOURCES=$($KC get $crd -n $NS -o name 2>/dev/null)
        for res in $RESOURCES; do
          echo "  Patching $res"
          $KC patch $res -n $NS --type=merge -p '{"metadata":{"finalizers":null}}' 2>/dev/null || true
        done
      done

      # Step 3: Also check utils namespace
      F5_UTILS_NS="${self.triggers.utils_namespace}"
      for crd in $F5_CRDS; do
        RESOURCES=$($KC get $crd -n $F5_UTILS_NS -o name 2>/dev/null)
        for res in $RESOURCES; do
          echo "  Patching $res (in $F5_UTILS_NS)"
          $KC patch $res -n $F5_UTILS_NS --type=merge -p '{"metadata":{"finalizers":null}}' 2>/dev/null || true
        done
      done

      # Step 4: Delete all F5 CRDs (cluster-scoped)
      # FLO's crd-installer expects to create these fresh. Stale CRDs from a
      # previous deploy cause conflicts and failed reconciliation.
      echo "Step 4: Deleting F5 CRDs..."
      for crd in $F5_CRDS; do
        echo "  Deleting CRD $crd"
        $KC delete crd $crd --timeout=30s 2>/dev/null || true
      done
      # Also catch any with fic.f5.com (IPAM CRDs)
      for crd in $($KC get crd -o name 2>/dev/null | grep 'fic\.f5\.com' | sed 's|customresourcedefinition.apiextensions.k8s.io/||'); do
        echo "  Deleting CRD $crd"
        $KC delete crd $crd --timeout=30s 2>/dev/null || true
      done

      echo "=== BNK cleanup complete ==="
    EOT
  }

  depends_on = [
    kubernetes_namespace_v1.operator,
    kubernetes_namespace_v1.utils,
    kubernetes_namespace_v1.gateway
  ]
}

# =============================================================================
# NAMESPACES
# =============================================================================

resource "kubernetes_namespace_v1" "operator" {
  metadata {
    name = var.operator_namespace
    labels = {
      "app.kubernetes.io/name"       = "f5-operator"
      "app.kubernetes.io/component"  = "bnk-operators"
      "app.kubernetes.io/managed-by" = "terraform"
      "f5.com/product"               = "bnk"
    }
    annotations = {
      "description" = "F5 BNK control plane + all components deployed by FLO via CNEInstance"
    }
  }
}

resource "kubernetes_namespace_v1" "utils" {
  metadata {
    name = var.utils_namespace
    labels = {
      "app.kubernetes.io/name"       = "f5-utils"
      "app.kubernetes.io/component"  = "bnk-utilities"
      "app.kubernetes.io/managed-by" = "terraform"
      "f5.com/product"               = "bnk"
    }
    annotations = {
      "description" = "F5 BNK utility components (IPAM if deployed separately)"
    }
  }
}

resource "kubernetes_namespace_v1" "gateway" {
  metadata {
    name = var.gateway_namespace
    labels = {
      "app.kubernetes.io/name"       = var.gateway_namespace
      "app.kubernetes.io/component"  = "gateway-api"
      "app.kubernetes.io/managed-by" = "terraform"
      "f5.com/product"               = "bnk"
    }
    annotations = {
      "description" = "Namespace for Gateway API resources (Gateway, HTTPRoute, etc.)"
    }
  }
}

# =============================================================================
# FAR IMAGE PULL SECRETS
# =============================================================================
# Create far-secret in every namespace. FLO + CNEInstance + CRD installer all
# need to pull images from repo.f5.com.

resource "kubernetes_secret_v1" "far_secret_operator" {
  metadata {
    name      = "far-secret"
    namespace = kubernetes_namespace_v1.operator.metadata[0].name
    labels = {
      "app.kubernetes.io/name"       = "far-auth"
      "app.kubernetes.io/managed-by" = "terraform"
      "f5.com/product"               = "bnk"
    }
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = local.docker_config_json
  }
}

resource "kubernetes_secret_v1" "far_secret_utils" {
  metadata {
    name      = "far-secret"
    namespace = kubernetes_namespace_v1.utils.metadata[0].name
    labels = {
      "app.kubernetes.io/name"       = "far-auth"
      "app.kubernetes.io/managed-by" = "terraform"
      "f5.com/product"               = "bnk"
    }
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = local.docker_config_json
  }
}

resource "kubernetes_secret_v1" "far_secret_gateway" {
  metadata {
    name      = "far-secret"
    namespace = kubernetes_namespace_v1.gateway.metadata[0].name
    labels = {
      "app.kubernetes.io/name"       = "far-auth"
      "app.kubernetes.io/managed-by" = "terraform"
      "f5.com/product"               = "bnk"
    }
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = local.docker_config_json
  }
}

# =============================================================================
# WRITE SERVICE ACCOUNT KEY TO TEMP FILE (for helm registry login)
# =============================================================================
# The scripts need a file path for `helm registry login`. We write the
# cne_pull_secret content to a temp file in the module workspace.

resource "local_sensitive_file" "service_account_key" {
  filename = "${path.module}/work/cne_pull_secret.json"
  content  = var.cne_pull_secret
}

# =============================================================================
# MANIFEST DOWNLOAD AND VERSION PARSING
# =============================================================================
# Downloads the BNK manifest chart from repo.f5.com using helm CLI.
# Parses out all component versions (FLO, cert-manager, CWC, etc.)

data "external" "manifest_download" {
  program = ["bash", "${path.module}/scripts/download-manifest.sh"]

  query = {
    manifest_version         = var.bnk_manifest_version
    chart_name               = "f5-bigip-k8s-manifest"
    work_dir                 = "${path.module}/work"
    service_account_key_file = local_sensitive_file.service_account_key.filename
  }

  depends_on = [local_sensitive_file.service_account_key]
}

data "external" "component_versions" {
  program = ["bash", "${path.module}/scripts/parse-versions.sh"]

  query = {
    manifest_file = data.external.manifest_download.result.manifest_file
  }

  depends_on = [data.external.manifest_download]
}

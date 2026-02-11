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
# LOCALS
# =============================================================================

locals {
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

  # All namespaces that need FAR pull secrets
  namespaces_with_secrets = {
    operator = var.operator_namespace
    utils    = var.utils_namespace
    gateway  = var.gateway_namespace
  }
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

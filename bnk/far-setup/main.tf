# bnk/far-setup/main.tf
# F5 BIG-IP Next for Kubernetes (BNK) 2.2 - FAR Setup
# Sets up F5 Artifact Registry authentication and downloads manifest

# =============================================================================
# LOCAL VARIABLES
# =============================================================================

locals {
  # Use new BNK naming, fall back to legacy SPK naming for backward compatibility
  effective_namespace        = var.bnk_namespace != "" ? var.bnk_namespace : (var.spk_namespace != "" ? var.spk_namespace : "f5-bnk")
  effective_manifest_version = var.bnk_manifest_version != "" ? var.bnk_manifest_version : var.spk_manifest_version

  # Create list of all namespaces that need FAR secrets
  far_namespaces = var.create_namespaces ? [
    local.effective_namespace,
    var.utils_namespace
    ] : [
    local.effective_namespace,
    var.utils_namespace
  ]

  # Service account key content
  service_account_key = file(var.service_account_key_file)

  # Base64 encoded authentication for docker config
  docker_auth = base64encode("_json_key_base64:${local.service_account_key}")
}

# =============================================================================
# KUBERNETES NAMESPACES (optional - prefer using bnk-namespaces module)
# =============================================================================

# Create BNK namespace for controller/TMM (only if create_namespaces = true)
resource "kubernetes_namespace_v1" "bnk" {
  count = var.create_namespaces ? 1 : 0

  metadata {
    name = local.effective_namespace
    labels = {
      "app.kubernetes.io/name"       = "bnk"
      "app.kubernetes.io/component"  = "controller"
      "app.kubernetes.io/managed-by" = "terraform"
      "f5.com/bnk-version"           = local.effective_manifest_version
    }
  }
}

# Create utils namespace for shared components (only if create_namespaces = true)
resource "kubernetes_namespace_v1" "utils" {
  count = var.create_namespaces ? 1 : 0

  metadata {
    name = var.utils_namespace
    labels = {
      "app.kubernetes.io/name"       = "bnk"
      "app.kubernetes.io/component"  = "utils"
      "app.kubernetes.io/managed-by" = "terraform"
      "f5.com/bnk-version"           = local.effective_manifest_version
    }
  }
}

# =============================================================================
# FAR AUTHENTICATION SECRETS
# =============================================================================

# Create FAR authentication secrets in BNK namespace
resource "kubernetes_secret_v1" "far_auth_bnk" {
  metadata {
    name      = "far-secret"
    namespace = local.effective_namespace
    labels = {
      "app.kubernetes.io/name"       = "bnk"
      "app.kubernetes.io/component"  = "far-auth"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "repo.f5.com" = {
          auth = local.docker_auth
        }
      }
    })
  }

  depends_on = [
    kubernetes_namespace_v1.bnk
  ]
}

# Create FAR authentication secrets in utils namespace
resource "kubernetes_secret_v1" "far_auth_utils" {
  metadata {
    name      = "far-secret"
    namespace = var.utils_namespace
    labels = {
      "app.kubernetes.io/name"       = "bnk"
      "app.kubernetes.io/component"  = "far-auth"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "repo.f5.com" = {
          auth = local.docker_auth
        }
      }
    })
  }

  depends_on = [
    kubernetes_namespace_v1.utils
  ]
}

# =============================================================================
# MANIFEST FILE DOWNLOAD AND PARSING
# =============================================================================

# Download and extract manifest file
data "external" "manifest_download" {
  program = ["bash", "${path.module}/scripts/download-manifest.sh"]

  query = {
    manifest_version         = local.effective_manifest_version
    chart_name               = var.manifest_chart_name
    work_dir                 = "${path.module}/work"
    service_account_key_file = var.service_account_key_file
  }
}

# Parse component versions from manifest
data "external" "component_versions" {
  program = ["bash", "${path.module}/scripts/parse-versions.sh"]

  query = {
    manifest_file = data.external.manifest_download.result.manifest_file
  }

  depends_on = [data.external.manifest_download]
}

# =============================================================================
# VALIDATION
# =============================================================================

# Validate that required component versions were parsed
resource "local_file" "version_validation" {
  filename = "${path.module}/work/versions-validated.json"
  content = jsonencode({
    validation_timestamp = timestamp()
    required_components = [
      "cert_manager",
      "flo"
    ]
    parsed_versions = data.external.component_versions.result
    validation_passed = alltrue([
      for component in ["cert_manager", "flo"] :
      lookup(data.external.component_versions.result, component, "") != ""
    ])
    note = "FLO manages: CWC, DSSM, Fluentd, F5Ingress, CRDs (common, service-proxy, deprecated)"
  })

  depends_on = [data.external.component_versions]
}

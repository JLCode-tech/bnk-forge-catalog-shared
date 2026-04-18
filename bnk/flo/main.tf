# bnk/flo/main.tf
# F5 Lifecycle Operator (FLO) Helm deployment
#
# Deploys FLO using helm_release — platform-agnostic.
# Kubernetes/Helm provider config is injected by BNK-Forge (bnk_forge_providers.tf).
#
# FLO manages the entire BNK control plane:
# - CRDs (GatewayClass, Gateway, HTTPRoute, etc.)
# - CWC (Cluster-Wide Controller)
# - DSSM (Distributed Session State Manager)
# - Observer, Fluentd, OTEL, RabbitMQ
# - TMM (via CNEInstance)

# =============================================================================
# KUBECONFIG FOR KUBECTL
# =============================================================================
# Platform-agnostic kubeconfig for kubectl in local-exec provisioners.
# local.forge_kubeconfig is injected by BNK-Forge via bnk_forge_providers.tf
# for any platform (EKS, AKS, GKE, OCP, generic).
# Falls back to var.forge_kubeconfig_content for standalone usage outside Forge.

resource "local_file" "kubeconfig" {
  filename        = "${path.module}/work/kubeconfig"
  file_permission = "0600"
  content         = try(local.forge_kubeconfig, var.forge_kubeconfig_content)
}

# =============================================================================
# LOCAL VALUES
# =============================================================================

locals {
  kubectl = "kubectl --kubeconfig ${local_file.kubeconfig.filename}"

  # TEEM URLs for connected licensing
  # Per F5 CloudDocs: https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/installing-bnk-dpu-using-f5-lifecycle-operator/installing/bnk-install-flo.html
  teem_urls = {
    cert_url           = "https://product.apis.f5.com/ee/v1"
    entitlement_url    = "https://product-s.apis.f5.com/ee/v1"
    initial_config_url = "https://product-s.apis.f5.com/ee/v1"
  }

  # Licensing configuration based on mode
  license_config = var.license_mode == "connected" ? {
    operationMode        = "connected"
    teemCertUrl          = local.teem_urls.cert_url
    teemEntitlementUrl   = local.teem_urls.entitlement_url
    teemInitialConfigUrl = local.teem_urls.initial_config_url
    jwt                  = var.jwt_token != "" ? var.jwt_token : null
    } : {
    operationMode     = "f5licenseproxy"
    f5LicenseProxyUrl = var.f5_license_proxy_url
  }
}

# =============================================================================
# ADOPT EXISTING CRDs — Fix for destroy/redeploy cycle
# =============================================================================
# Helm never deletes CRDs on uninstall (by design, to protect user data).
# On re-install to a different namespace, Helm refuses because the CRDs have
# ownership annotations pointing to the old release/namespace.
#
# This pre-install step re-labels any existing FLO CRDs so Helm can adopt them.
# No AWS CLI needed — kubectl uses the same auth as the kubernetes provider.

resource "null_resource" "adopt_flo_crds" {
  triggers = {
    flo_namespace = var.flo_namespace
  }

  provisioner "local-exec" {
    command = <<-EOT
      KC="${local.kubectl}"
      echo "=== Adopting existing FLO CRDs for namespace ${var.flo_namespace} ==="

      # Find all CRDs owned by any previous FLO Helm release
      CRDS=$($KC get crd -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.annotations.meta\.helm\.sh/release-name}{"\n"}{end}' 2>/dev/null \
        | grep -E '\tflo$' | awk '{print $1}')

      if [ -z "$CRDS" ]; then
        echo "No existing FLO CRDs found — clean install"
        exit 0
      fi

      ADOPTED=0
      for crd in $CRDS; do
        $KC annotate crd "$crd" \
          meta.helm.sh/release-name=flo \
          meta.helm.sh/release-namespace=${var.flo_namespace} \
          --overwrite 2>/dev/null && ADOPTED=$((ADOPTED+1))
      done

      echo "Adopted $ADOPTED FLO CRDs for namespace ${var.flo_namespace}"
    EOT
  }
}

resource "null_resource" "cleanup_orphaned_flo_release" {
  depends_on = [null_resource.adopt_flo_crds]

  triggers = {
    flo_namespace = var.flo_namespace
  }

  provisioner "local-exec" {
    command = <<-EOT
      KC="${local.kubectl}"
      echo "=== Checking for orphaned FLO Helm release ==="

      # Check if a failed helm release secret exists
      FAILED_SECRETS=$($KC get secrets -n ${var.flo_namespace} \
        -l "owner=helm,name=flo,status=failed" \
        -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)

      if [ -z "$FAILED_SECRETS" ]; then
        echo "No orphaned FLO release found — proceeding"
        exit 0
      fi

      echo "Found orphaned FLO release secrets: $FAILED_SECRETS"
      echo "Cleaning up orphaned release..."

      # Delete all helm release secrets for flo (failed or pending-install)
      $KC delete secrets -n ${var.flo_namespace} \
        -l "owner=helm,name=flo" 2>/dev/null || true

      # Delete deployment/resources left behind
      $KC delete deployment -n ${var.flo_namespace} \
        -l "app.kubernetes.io/instance=flo" --ignore-not-found=true 2>/dev/null || true
      $KC delete service -n ${var.flo_namespace} \
        -l "app.kubernetes.io/instance=flo" --ignore-not-found=true 2>/dev/null || true
      $KC delete serviceaccount -n ${var.flo_namespace} \
        -l "app.kubernetes.io/instance=flo" --ignore-not-found=true 2>/dev/null || true
      $KC delete configmap -n ${var.flo_namespace} \
        -l "app.kubernetes.io/instance=flo" --ignore-not-found=true 2>/dev/null || true
      $KC delete clusterrole \
        -l "app.kubernetes.io/instance=flo" --ignore-not-found=true 2>/dev/null || true
      $KC delete clusterrolebinding \
        -l "app.kubernetes.io/instance=flo" --ignore-not-found=true 2>/dev/null || true
      $KC delete role -n ${var.flo_namespace} \
        -l "app.kubernetes.io/instance=flo" --ignore-not-found=true 2>/dev/null || true
      $KC delete rolebinding -n ${var.flo_namespace} \
        -l "app.kubernetes.io/instance=flo" --ignore-not-found=true 2>/dev/null || true

      echo "Orphaned FLO release cleaned up successfully"
    EOT
  }
}

# =============================================================================
# F5 LIFECYCLE OPERATOR HELM RELEASE
# =============================================================================

resource "helm_release" "flo" {
  depends_on = [null_resource.adopt_flo_crds, null_resource.cleanup_orphaned_flo_release]

  name       = "flo"
  repository = "oci://repo.f5.com/charts"
  chart      = "f5-lifecycle-operator"
  version    = var.flo_version
  namespace  = var.flo_namespace

  timeout = 600
  wait    = true

  values = [
    yamlencode({
      # Global configuration
      global = {
        imagePullSecrets = [
          { name = var.far_secret_name }
        ]
        certmgr = {
          clusterIssuer = var.cluster_issuer_name
        }
      }

      # Image configuration
      image = {
        repository = "repo.f5.com/images"
        pullPolicy = "IfNotPresent"
      }

      # Image pull secrets (also at top level for compatibility)
      imagePullSecrets = [
        { name = var.far_secret_name }
      ]

      # Service account
      serviceAccount = {
        create = true
        name   = "flo-controller"
      }

      # Licensing configuration
      license = local.license_config

      # IPAM operator
      ipam = {
        enabled   = true
        namespace = "f5-utils"
      }

      # Container platform (Generic, AWS, Azure, etc.)
      # Setting this to AWS tells FLO the deployment target is AWS,
      # affecting GRPC endpoint config and cloud-specific networking.
      containerPlatform = var.container_platform

      # CRD management
      crds = {
        install = true
      }
    })
  ]
}

# =============================================================================
# CPCL KEY — Download and apply the real F5 JWT verification key
# =============================================================================
# The FLO Helm chart deploys a placeholder cpcl-key-cm ConfigMap with "..."
# values. CWC needs the REAL key to verify JWT license tokens.

resource "null_resource" "apply_cpcl_key" {
  depends_on = [helm_release.flo]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Downloading real CPCL key from F5 CloudDocs ==="

      CPCL_URL="https://clouddocs.f5.com/service-proxy/latest/cpcl-key.yaml"
      CPCL_FILE="/tmp/cpcl-key-$$.yaml"

      if ! curl -sL --fail --connect-timeout 30 --max-time 60 "$CPCL_URL" -o "$CPCL_FILE"; then
        echo "WARNING: Failed to download CPCL key. License activation may fail."
        exit 0
      fi

      # Validate not HTML
      if grep -q "<!DOCTYPE html>" "$CPCL_FILE" 2>/dev/null; then
        echo "WARNING: Got HTML instead of YAML. CPCL key not applied."
        rm -f "$CPCL_FILE"
        exit 0
      fi

      # Validate has RSA key material
      if ! grep -q '"n":' "$CPCL_FILE" 2>/dev/null; then
        echo "WARNING: CPCL key missing RSA material. Skipping."
        rm -f "$CPCL_FILE"
        exit 0
      fi

      echo "Applying real CPCL key to ${var.flo_namespace} namespace"
      ${local.kubectl} apply -f "$CPCL_FILE" -n ${var.flo_namespace} 2>&1
      rm -f "$CPCL_FILE"
      echo "CPCL key applied successfully"
    EOT
  }
}

# =============================================================================
# LICENSE SECRET CLEANUP — Clear stale license state
# =============================================================================

resource "null_resource" "cleanup_license_secrets" {
  depends_on = [null_resource.apply_cpcl_key]

  triggers = {
    jwt_hash = sha256(var.jwt_token)
  }

  provisioner "local-exec" {
    command = <<-EOT
      KC="${local.kubectl}"
      echo "=== Cleaning stale license secrets in ${var.flo_namespace} ==="
      NS="${var.flo_namespace}"

      for secret in activationmessage activationstatus activationtimestamp \
                    configreport configreportsignedackresponse context csr \
                    customerprovidedid digitalassetid digitalassetname \
                    digitalassetversion entitlements initialregistrationstatus \
                    licensekey licensestatus modeofoperation previousreportname \
                    previousreportverifieddate productname statehistory \
                    statesofdecay switchlicensestatus telemetrystatus \
                    telemetryreports; do
        $KC delete secret -n "$NS" "$secret" 2>/dev/null && \
          echo "  cleaned: $secret" || true
      done

      echo "License secrets cleanup complete"
    EOT
  }
}

# =============================================================================
# VERIFY FLO IS READY
# =============================================================================

resource "time_sleep" "wait_for_flo" {
  depends_on = [
    helm_release.flo,
    null_resource.apply_cpcl_key,
    null_resource.cleanup_license_secrets
  ]

  create_duration = "30s"
}

resource "null_resource" "verify_flo" {
  depends_on = [time_sleep.wait_for_flo]

  provisioner "local-exec" {
    command = <<-EOT
      KC="${local.kubectl}"
      echo "=== Verifying F5 Lifecycle Operator ==="

      # Check FLO pods
      $KC get pods -n ${var.flo_namespace} -l app=flo

      # Verify CRDs
      echo ""
      echo "=== CRDs installed by FLO ==="
      $KC get crd | grep -E "f5.com|gateway.networking.k8s.io" || echo "CRDs not yet available"

      # Check CPCL key
      echo ""
      echo "=== CPCL key ==="
      CPCL_N=$($KC get configmap cpcl-key-cm -n ${var.flo_namespace} -o jsonpath='{.data.jwt\.key}' 2>/dev/null | grep -o '"n":"[^"]*"' | head -1 | cut -d'"' -f4)
      if [ -z "$CPCL_N" ] || [ "$CPCL_N" = "..." ]; then
        echo "WARNING: CPCL key has placeholder values"
      else
        echo "OK: CPCL key has real RSA material"
      fi

      # Check license
      echo ""
      echo "=== License status ==="
      STATUS=$($KC get secret licensestatus -n ${var.flo_namespace} -o jsonpath='{.data.licensestatus}' 2>/dev/null | base64 -d 2>/dev/null)
      if echo "$STATUS" | grep -q '"IsActive":true'; then
        echo "License: ACTIVE"
      else
        echo "License: not yet active (CWC may still be initializing)"
      fi

      echo ""
      echo "FLO verification complete"
    EOT
  }
}

# infrastructure-modules/spk-2.1/flo/main.tf
# F5 Lifecycle Operator (FLO) Helm deployment

# =============================================================================
# LOCAL VALUES
# =============================================================================

# TEEM URLs by environment (for licensing)
locals {
  teem_urls = {
    production = {
      cert_url           = "https://product.apis.f5.com/ee/v1"
      entitlement_url    = "https://product-s.apis.f5.com/ee/v1"
      initial_config_url = "https://product-s.apis.f5.com/ee/v1"
    }
    test = {
      cert_url           = "https://product-tst.apis.f5networks.net/ee/v1"
      entitlement_url    = "https://product-s-tst.apis.f5networks.net/ee/v1"
      initial_config_url = "https://product-s-tst.apis.f5networks.net/ee/v1"
    }
  }

  selected_teem = local.teem_urls[var.license_environment]

  # Licensing configuration based on mode
  license_config = var.license_mode == "connected" ? {
    operationMode        = "connected"
    teemCertUrl          = local.selected_teem.cert_url
    teemEntitlementUrl   = local.selected_teem.entitlement_url
    teemInitialConfigUrl = local.selected_teem.initial_config_url
    jwt                  = var.jwt_token != "" ? var.jwt_token : null
    } : {
    operationMode     = "f5licenseproxy"
    f5LicenseProxyUrl = var.f5_license_proxy_url
  }
}

# =============================================================================
# NAMESPACE REFERENCES
# =============================================================================
# Note: The FLO namespace (f5-operator) is created by the bnk-namespaces module.
# We use data sources to reference existing namespaces instead of creating them.

data "kubernetes_namespace_v1" "flo" {
  metadata {
    name = var.flo_namespace
  }
}

# IPAM namespace - lookup only. Created by bnk-namespaces module (f5-utils).
# Previously this was a resource that would fail on redeploy when the namespace
# already existed. Using a data source avoids the conflict.
data "kubernetes_namespace_v1" "ipam" {
  count = var.enable_ipam_operator && var.ipam_namespace != var.flo_namespace ? 1 : 0

  metadata {
    name = var.ipam_namespace
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
# Safe to run when no CRDs exist (kubectl annotate --overwrite is idempotent).

resource "null_resource" "adopt_flo_crds" {
  # Re-run whenever the target namespace changes
  triggers = {
    flo_namespace = var.flo_namespace
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Adopting existing FLO CRDs for namespace ${var.flo_namespace} ==="

      # Find all CRDs owned by any previous FLO Helm release
      CRDS=$(kubectl get crd -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.annotations.meta\.helm\.sh/release-name}{"\n"}{end}' 2>/dev/null \
        | grep -E '\tflo$' | awk '{print $1}')

      if [ -z "$CRDS" ]; then
        echo "No existing FLO CRDs found — clean install"
        exit 0
      fi

      ADOPTED=0
      for crd in $CRDS; do
        kubectl annotate crd "$crd" \
          meta.helm.sh/release-name=flo \
          meta.helm.sh/release-namespace=${var.flo_namespace} \
          --overwrite 2>/dev/null && ADOPTED=$((ADOPTED+1))
      done

      echo "✓ Adopted $ADOPTED FLO CRDs for namespace ${var.flo_namespace}"
    EOT
  }
}

# =============================================================================
# F5 LIFECYCLE OPERATOR HELM RELEASE
# =============================================================================

resource "helm_release" "flo" {
  depends_on = [
    data.kubernetes_namespace_v1.flo,
    null_resource.adopt_flo_crds,
    var.cert_manager_ready,
    var.far_setup_complete
  ]

  name       = "flo"
  repository = var.flo_chart_repository
  chart      = "f5-lifecycle-operator"
  version    = var.flo_version
  namespace  = var.flo_namespace

  timeout = 600
  wait    = true

  values = [
    yamlencode({
      # Global configuration - includes cert-manager ClusterIssuer
      # Per F5 BNK 2.2 GA docs: global.certmgr.clusterIssuer must be set
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
        repository = var.image_registry
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

      # IPAM operator configuration
      ipam = {
        enabled   = var.enable_ipam_operator
        namespace = var.ipam_namespace
      }

      # Resource requests and limits
      resources = {
        requests = {
          cpu    = var.flo_cpu_request
          memory = var.flo_memory_request
        }
        limits = {
          cpu    = var.flo_cpu_limit
          memory = var.flo_memory_limit
        }
      }

      # Node placement
      nodeSelector = var.node_selector
      tolerations  = var.tolerations

      # Security context
      securityContext = {
        runAsNonRoot = true
        runAsUser    = 1000
        fsGroup      = 1000
      }

      # Operator settings
      operator = {
        watchNamespace = "" # Empty means watch all namespaces
        leaderElection = {
          enabled = true
        }
      }

      # CRD management (FLO automatically installs CRDs)
      crds = {
        install = true # FLO installs BnkGatewayClass and other CRDs
      }
    })
  ]
}

# =============================================================================
# CPCL KEY — Download and apply the real F5 JWT verification key
# =============================================================================
# The FLO Helm chart deploys a placeholder cpcl-key-cm ConfigMap with "..."
# values for the RSA key material. CWC needs the REAL key to verify JWT
# license tokens. We download it from F5 CloudDocs and overwrite the placeholder.
#
# This MUST happen after FLO Helm install (which creates the ConfigMap) but
# before CWC attempts JWT verification (which happens on CWC pod startup).

resource "null_resource" "apply_cpcl_key" {
  depends_on = [helm_release.flo]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Downloading real CPCL key from F5 CloudDocs ==="

      # Download the real CPCL key (contains RSA public keys for JWT verification)
      CPCL_URL="https://clouddocs.f5.com/service-proxy/latest/cpcl-key.yaml"
      CPCL_FILE="/tmp/cpcl-key-$$.yaml"

      if ! curl -sL --fail --connect-timeout 30 --max-time 60 "$CPCL_URL" -o "$CPCL_FILE"; then
        echo "WARNING: Failed to download CPCL key from $CPCL_URL"
        echo "License activation may fail. You can manually apply the key later:"
        echo "  kubectl apply -f <cpcl-key.yaml> -n ${var.flo_namespace}"
        exit 0  # Don't fail the deployment — key can be applied later
      fi

      # Validate the downloaded file has real key data (not HTML error page)
      if grep -q "<!DOCTYPE html>" "$CPCL_FILE" 2>/dev/null; then
        echo "WARNING: Got HTML instead of YAML from F5 CloudDocs. CPCL key not applied."
        rm -f "$CPCL_FILE"
        exit 0
      fi

      # Validate it has actual RSA key material (not placeholders)
      if ! grep -q '"n":' "$CPCL_FILE" 2>/dev/null; then
        echo "WARNING: CPCL key file missing RSA 'n' field. Skipping."
        rm -f "$CPCL_FILE"
        exit 0
      fi

      echo "=== Applying real CPCL key to ${var.flo_namespace} namespace ==="
      kubectl apply -f "$CPCL_FILE" -n ${var.flo_namespace} 2>&1

      rm -f "$CPCL_FILE"
      echo "✓ Real CPCL key applied successfully"
    EOT
  }
}

# =============================================================================
# LICENSE SECRET CLEANUP — Clear stale license state for fresh activation
# =============================================================================
# If redeploying FLO with a new JWT token, old license secrets from a previous
# activation attempt must be cleaned up. CWC checks these on startup and may
# skip activation if it sees old state.

resource "null_resource" "cleanup_license_secrets" {
  depends_on = [null_resource.apply_cpcl_key]

  # Re-run cleanup whenever jwt_token changes
  triggers = {
    jwt_hash = sha256(var.jwt_token)
  }

  provisioner "local-exec" {
    command = <<-EOT
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
        kubectl delete secret -n "$NS" "$secret" 2>/dev/null && \
          echo "  cleaned: $secret" || true
      done

      echo "✓ License secrets cleanup complete"
    EOT
  }
}

# =============================================================================
# WAIT FOR FLO TO BE READY
# =============================================================================

resource "time_sleep" "wait_for_flo" {
  depends_on = [
    helm_release.flo,
    null_resource.apply_cpcl_key,
    null_resource.cleanup_license_secrets
  ]

  create_duration = "30s" # Wait for FLO operator to become ready
}

# Verify FLO deployment and license activation
resource "null_resource" "verify_flo" {
  depends_on = [time_sleep.wait_for_flo]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Verifying F5 Lifecycle Operator Deployment ==="

      # Check FLO pods
      kubectl get pods -n ${var.flo_namespace} -l app=flo

      # Check IPAM pods (if enabled)
      if [ "${var.enable_ipam_operator}" = "true" ]; then
        kubectl get pods -n ${var.ipam_namespace} -l app=ipam-operator
      fi

      # Verify CRDs installed by FLO
      echo ""
      echo "=== Verifying CRDs installed by FLO ==="
      kubectl get crd | grep -E "gatewayclass|gateway" || echo "Gateway CRDs not yet available"

      # Verify CPCL key has real data (not placeholders)
      echo ""
      echo "=== Verifying CPCL key ==="
      CPCL_N=$(kubectl get configmap cpcl-key-cm -n ${var.flo_namespace} -o jsonpath='{.data.jwt\.key}' 2>/dev/null | grep -o '"n":"[^"]*"' | head -1 | cut -d'"' -f4)
      if [ -z "$CPCL_N" ] || [ "$CPCL_N" = "..." ]; then
        echo "WARNING: CPCL key still has placeholder values! License activation will fail."
        echo "Run: kubectl apply -f <cpcl-key.yaml> -n ${var.flo_namespace}"
      else
        echo "✓ CPCL key has real RSA key material (n field length: $${#CPCL_N})"
      fi

      # Check CWC license status
      echo ""
      echo "=== Checking license status ==="
      STATUS=$(kubectl get secret licensestatus -n ${var.flo_namespace} -o jsonpath='{.data.licensestatus}' 2>/dev/null | base64 -d 2>/dev/null)
      if echo "$STATUS" | grep -q '"IsActive":true'; then
        echo "✓ License is ACTIVE"
        echo "$STATUS" | grep -o '"EntitlementType":"[^"]*"' || true
        echo "$STATUS" | grep -o '"LicenseExpiryDate":"[^"]*"' || true
      else
        echo "⚠ License not yet active. CWC may still be initializing."
        echo "Check: kubectl logs -n ${var.flo_namespace} -l app=cwc -c f5-spk-cwc --tail=20"
      fi

      echo ""
      echo "✓ FLO deployment verification complete"
    EOT
  }
}

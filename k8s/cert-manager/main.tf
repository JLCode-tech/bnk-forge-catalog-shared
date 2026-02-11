# k8s/cert-manager/main.tf
# Jetstack cert-manager deployment for BNK 2.2 GA
#
# Per F5 CloudDocs BNK 2.2 GA:
# "For this setup, we recommend an open-source version of Cert Manager"
# "F5 tested BIG-IP Next for Kubernetes with Jetstack Cert Manager v1.16.1"
# Reference: https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/cert-manager.html
#
# DESIGN: Uses null_resource + kubectl apply for cert-manager CRD resources
# (ClusterIssuers, Certificates) instead of kubernetes_manifest. This avoids
# the chicken-and-egg problem where kubernetes_manifest needs CRDs at plan
# time, but CRDs are created by the helm_release in the same module.
# On a fresh cluster (or after destroy), CRDs don't exist yet at plan time.
#
# CRD CLEANUP: Helm's default resource-policy is "keep" for CRDs, which
# causes stale CRDs to persist across destroy/deploy cycles and break the
# webhook bootstrap. We set crds.keep=false so helm uninstall cleans them.

# =============================================================================
# CERT-MANAGER NAMESPACE
# =============================================================================

resource "kubernetes_namespace_v1" "cert_manager" {
  count = var.create_namespace ? 1 : 0

  metadata {
    name = var.namespace

    labels = {
      "app.kubernetes.io/name"       = "cert-manager"
      "app.kubernetes.io/component"  = "certificate-management"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# =============================================================================
# JETSTACK CERT-MANAGER HELM RELEASE
# =============================================================================
# Using official Jetstack cert-manager chart as recommended by F5 BNK 2.2 GA docs

resource "helm_release" "cert_manager" {
  depends_on = [kubernetes_namespace_v1.cert_manager]

  name       = var.release_name
  namespace  = var.namespace
  chart      = "cert-manager"
  repository = "https://charts.jetstack.io"
  version    = var.cert_manager_version

  # Values for cert-manager configuration
  values = [
    yamlencode({
      # Install CRDs - required for cert-manager to function
      crds = {
        enabled = true
        keep    = false # CRITICAL: Remove CRDs on helm uninstall to prevent
        # stale CRDs breaking webhook bootstrap on next deploy
      }

      # Global settings
      global = {
        leaderElection = {
          namespace = var.namespace
        }
      }

      # Startup API check - disabled to avoid timeout issues on slower clusters
      startupapicheck = {
        enabled = false
      }

      # Webhook configuration
      webhook = {
        replicaCount   = var.webhook_replicas
        timeoutSeconds = 30
      }

      # CA Injector configuration
      cainjector = {
        replicaCount = var.cainjector_replicas
      }

      # Controller configuration
      replicaCount = var.controller_replicas

      # Resource requests/limits (optional)
      resources = var.resources
    })
  ]

  # Wait for resources to be ready
  wait          = true
  wait_for_jobs = false
  timeout       = var.helm_timeout
}

# =============================================================================
# WAIT FOR CERT-MANAGER WEBHOOK TO BE READY
# =============================================================================
# The webhook must be fully ready before we can create cert-manager CRD
# resources (ClusterIssuers, Certificates). The webhook needs its TLS cert
# from the cainjector, which takes 30-60s after helm install.

resource "null_resource" "wait_for_cert_manager" {
  depends_on = [helm_release.cert_manager]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Waiting for cert-manager webhook to be ready ==="

      # Wait for all cert-manager deployments to be available
      kubectl wait --for=condition=Available deployment/${var.release_name} \
        -n ${var.namespace} --timeout=120s

      kubectl wait --for=condition=Available deployment/${var.release_name}-webhook \
        -n ${var.namespace} --timeout=120s

      kubectl wait --for=condition=Available deployment/${var.release_name}-cainjector \
        -n ${var.namespace} --timeout=120s

      # Verify CRDs are installed
      echo "=== Verifying cert-manager CRDs ==="
      kubectl get crd | grep -E "cert-manager.io"

      # Extra wait for webhook to be fully serving (cainjector needs to inject CA)
      echo "Waiting 15s for webhook TLS bootstrap..."
      sleep 15

      echo "cert-manager is ready"
    EOT
  }
}

# =============================================================================
# SELF-SIGNED CLUSTER ISSUER + CA
# =============================================================================
# Per F5 CloudDocs: Create self-signed CA and ClusterIssuer for BNK certs.
#
# Uses kubectl apply instead of kubernetes_manifest to avoid plan-time CRD
# dependency. The depends_on ensures helm_release (which installs CRDs) runs
# first.

resource "null_resource" "cluster_issuers" {
  count = var.create_cluster_issuer ? 1 : 0

  depends_on = [null_resource.wait_for_cert_manager]

  triggers = {
    cluster_issuer_name = var.cluster_issuer_name
    ca_certificate_name = var.ca_certificate_name
    namespace           = var.namespace
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Creating ClusterIssuers and CA Certificate ==="
      cat <<'YAML' | kubectl apply -f -
      apiVersion: cert-manager.io/v1
      kind: ClusterIssuer
      metadata:
        name: selfsigned-cluster-issuer
      spec:
        selfSigned: {}
      ---
      apiVersion: cert-manager.io/v1
      kind: Certificate
      metadata:
        name: ${var.ca_certificate_name}
        namespace: ${var.namespace}
      spec:
        isCA: true
        commonName: ${var.ca_certificate_name}
        secretName: ${var.ca_certificate_name}
        issuerRef:
          name: selfsigned-cluster-issuer
          kind: ClusterIssuer
          group: cert-manager.io
      YAML

      # Wait for CA certificate to be issued before creating the CA issuer
      echo "Waiting for CA certificate to be ready..."
      kubectl wait --for=condition=Ready certificate/${var.ca_certificate_name} \
        -n ${var.namespace} --timeout=120s

      cat <<'YAML' | kubectl apply -f -
      apiVersion: cert-manager.io/v1
      kind: ClusterIssuer
      metadata:
        name: ${var.cluster_issuer_name}
      spec:
        ca:
          secretName: ${var.ca_certificate_name}
      YAML

      # Verify
      echo "=== Verifying ClusterIssuers ==="
      kubectl get clusterissuers
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "=== Cleaning up ClusterIssuers and CA Certificate ==="
      kubectl delete clusterissuer ${self.triggers.cluster_issuer_name} --ignore-not-found=true 2>/dev/null || true
      kubectl delete certificate ${self.triggers.ca_certificate_name} -n ${self.triggers.namespace} --ignore-not-found=true 2>/dev/null || true
      kubectl delete clusterissuer selfsigned-cluster-issuer --ignore-not-found=true 2>/dev/null || true
      echo "ClusterIssuer cleanup complete"
    EOT
  }
}

# =============================================================================
# CWC CERTIFICATES — NOT NEEDED (FLO auto-manages these)
# =============================================================================
# IMPORTANT: The F5 CloudDocs cwc-certificate.html page describes the OLD
# pre-FLO manual deployment approach using f5-cert-gen. With FLO v2.9.27+,
# CWC certificates are created automatically as cert-manager Certificate CRDs:
#
#   Verified on live cluster (aws-sydney-bnk-demo-cluster, BNK 2.2 GA):
#   - tls-spkcwc-grpc-svr-secret   (CWC gRPC server)
#   - tls-cwc-amqp-clt-secret      (CWC AMQP client)
#   - tls-csmqkview-grpc-svr-secret (QKView gRPC server)
#   - tls-csmqkview-grpc-clt-secret (QKView gRPC client)
#
# These are all type kubernetes.io/tls, managed by cert-manager, created by FLO.
# DO NOT create cwc-license-certs, qkview-server-certs, or qkview-client-certs.

# =============================================================================
# OTEL CERTIFICATES (replaces static Helm-embedded cert from FLO)
# =============================================================================
# Per F5 CloudDocs: https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/otl-certs.html
#
# FLO Helm deploys external-otelsvr-secret as a STATIC Opaque secret that
# does NOT auto-rotate. By creating cert-manager Certificate CRDs targeting
# these secret names, we replace the static cert with managed, auto-rotating ones.

resource "null_resource" "otel_certificates" {
  count = var.create_otel_certs && var.create_cluster_issuer ? 1 : 0

  depends_on = [null_resource.cluster_issuers]

  triggers = {
    cluster_issuer_name = var.cluster_issuer_name
    bnk_namespace       = var.bnk_namespace
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Creating OTEL Managed Certificates ==="
      cat <<'YAML' | kubectl apply -f -
      apiVersion: cert-manager.io/v1
      kind: Certificate
      metadata:
        name: external-otelsvr
        namespace: ${var.bnk_namespace}
      spec:
        secretName: external-otelsvr-secret
        commonName: f5net.com
        subject:
          countries: ["US"]
          provinces: ["Washington"]
          localities: ["Seattle"]
          organizations: ["F5 Networks"]
          organizationalUnits: ["PD"]
        emailAddresses: ["clientcert@f5net.com"]
        duration: "8640h"
        renewBefore: "720h"
        issuerRef:
          name: ${var.cluster_issuer_name}
          kind: ClusterIssuer
          group: cert-manager.io
        privateKey:
          rotationPolicy: Always
          encoding: PKCS1
          algorithm: RSA
          size: 4096
        revisionHistoryLimit: 10
      ---
      apiVersion: cert-manager.io/v1
      kind: Certificate
      metadata:
        name: external-f5ingotelsvr
        namespace: ${var.bnk_namespace}
      spec:
        secretName: external-f5ingotelsvr-secret
        commonName: f5net.com
        subject:
          countries: ["US"]
          provinces: ["Washington"]
          localities: ["Seattle"]
          organizations: ["F5 Networks"]
          organizationalUnits: ["PD"]
        emailAddresses: ["clientcert@f5net.com"]
        duration: "8640h"
        renewBefore: "720h"
        issuerRef:
          name: ${var.cluster_issuer_name}
          kind: ClusterIssuer
          group: cert-manager.io
        privateKey:
          rotationPolicy: Always
          encoding: PKCS1
          algorithm: RSA
          size: 4096
        revisionHistoryLimit: 10
      YAML

      # Wait for certificates to be issued
      echo "Waiting for OTEL certificates to be ready..."
      kubectl wait --for=condition=Ready certificate/external-otelsvr \
        -n ${var.bnk_namespace} --timeout=120s || echo "WARN: external-otelsvr not ready yet"
      kubectl wait --for=condition=Ready certificate/external-f5ingotelsvr \
        -n ${var.bnk_namespace} --timeout=120s || echo "WARN: external-f5ingotelsvr not ready yet"

      echo "=== OTEL Certificate Status ==="
      kubectl get certificates -n ${var.bnk_namespace}
      echo ""
      echo "OK: OTEL certs managed by cert-manager with auto-rotation"
      echo "    (CWC certs are auto-managed by FLO — no action needed)"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "=== Cleaning up OTEL Certificates ==="
      kubectl delete certificate external-otelsvr -n ${self.triggers.bnk_namespace} --ignore-not-found=true 2>/dev/null || true
      kubectl delete certificate external-f5ingotelsvr -n ${self.triggers.bnk_namespace} --ignore-not-found=true 2>/dev/null || true
      echo "OTEL certificate cleanup complete"
    EOT
  }
}

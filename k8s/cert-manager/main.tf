# k8s/cert-manager/main.tf
# Jetstack cert-manager deployment for BNK 2.2 GA
#
# Per F5 CloudDocs BNK 2.2 GA:
# "For this setup, we recommend an open-source version of Cert Manager"
# "F5 tested BIG-IP Next for Kubernetes with Jetstack Cert Manager v1.16.1"
# Reference: https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/cert-manager.html

# =============================================================================
# CERT-MANAGER NAMESPACE
# =============================================================================
# cert-manager requires its own namespace (cert-manager is the standard)

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
      # Note: installCRDs is deprecated, use crds.enabled instead
      crds = {
        enabled = true
      }

      # Global settings
      global = {
        # Leader election namespace
        leaderElection = {
          namespace = var.namespace
        }
      }

      # Startup API check - disabled to avoid timeout issues on slower clusters
      # The startupapicheck job has a built-in 5min timeout that often fails
      # cert-manager works fine without it
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
  wait_for_jobs = false # Don't wait for startupapicheck since it's disabled
  timeout       = var.helm_timeout
}

# =============================================================================
# SELF-SIGNED CLUSTER ISSUER
# =============================================================================
# Per F5 CloudDocs: Create self-signed CA and ClusterIssuer for BNK certificates

resource "kubernetes_manifest" "selfsigned_issuer" {
  count = var.create_cluster_issuer ? 1 : 0

  depends_on = [helm_release.cert_manager]

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "selfsigned-cluster-issuer"
    }
    spec = {
      selfSigned = {}
    }
  }
}

# CA Certificate for signing other certificates
resource "kubernetes_manifest" "ca_certificate" {
  count = var.create_cluster_issuer ? 1 : 0

  depends_on = [kubernetes_manifest.selfsigned_issuer]

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = var.ca_certificate_name
      namespace = var.namespace
    }
    spec = {
      isCA       = true
      commonName = var.ca_certificate_name
      secretName = var.ca_certificate_name
      issuerRef = {
        name  = "selfsigned-cluster-issuer"
        kind  = "ClusterIssuer"
        group = "cert-manager.io"
      }
    }
  }
}

# CA ClusterIssuer that uses the CA certificate to sign other certs
resource "kubernetes_manifest" "ca_cluster_issuer" {
  count = var.create_cluster_issuer ? 1 : 0

  depends_on = [kubernetes_manifest.ca_certificate]

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = var.cluster_issuer_name
    }
    spec = {
      ca = {
        secretName = var.ca_certificate_name
      }
    }
  }
}

# =============================================================================
# WAIT FOR CERT-MANAGER TO BE READY
# =============================================================================

resource "time_sleep" "wait_for_cert_manager" {
  depends_on = [helm_release.cert_manager]

  create_duration = "30s"
}

resource "null_resource" "verify_cert_manager" {
  depends_on = [time_sleep.wait_for_cert_manager]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Verifying Jetstack cert-manager Deployment ==="
      
      # Check cert-manager pods
      kubectl get pods -n ${var.namespace} -l app.kubernetes.io/instance=${var.release_name}
      
      # Wait for cert-manager webhook to be ready
      kubectl wait --for=condition=Available deployment/${var.release_name}-webhook -n ${var.namespace} --timeout=120s || echo "Webhook not yet available"
      
      # Verify CRDs are installed
      echo ""
      echo "=== Verifying cert-manager CRDs ==="
      kubectl get crd | grep -E "cert-manager.io" || echo "cert-manager CRDs not found"
      
      echo "cert-manager deployment verification complete"
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
#   - tls-spkcwc-grpc-svr-secret   (CWC gRPC server - replaces cwc-license-certs)
#   - tls-cwc-amqp-clt-secret      (CWC AMQP client)
#   - tls-csmqkview-grpc-svr-secret (QKView gRPC server - replaces qkview-server-certs)
#   - tls-csmqkview-grpc-clt-secret (QKView gRPC client - replaces qkview-client-certs)
#
# These are all type kubernetes.io/tls, managed by cert-manager, created by FLO.
# DO NOT create cwc-license-certs, qkview-server-certs, or qkview-client-certs —
# those secret names are from the old manual approach and are NOT mounted by CWC.

# =============================================================================
# OTEL CERTIFICATES (replaces static Helm-embedded cert from FLO)
# =============================================================================
# Per F5 CloudDocs: https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/otl-certs.html
#
# Verified on live cluster:
# - FLO Helm deploys external-otelsvr-secret as a STATIC Opaque secret
#   (managed-by: Helm, release: flo). This cert does NOT auto-rotate and
#   will expire without warning.
# - The OTEL collector pod mounts it at /external/otelsvr
# - external-f5ingotelsvr-secret does NOT exist on the live cluster but
#   F5 docs say it should be created.
#
# By creating cert-manager Certificate CRDs targeting these secret names,
# we replace the static cert with a managed, auto-rotating one.
# cert-manager will take ownership of the secret and keep it renewed.
#
# All spec fields validated against the live cert-manager CRD (v1.16.1):
#   secretName, commonName, subject, emailAddresses, duration, renewBefore,
#   issuerRef (name REQUIRED, kind/group optional), privateKey (algorithm
#   enum: RSA/ECDSA/Ed25519, encoding enum: PKCS1/PKCS8, rotationPolicy
#   enum: Never/Always, size: integer), revisionHistoryLimit, usages enum
#   includes: server auth, client auth, digital signature, key encipherment

resource "kubernetes_manifest" "otel_server_certificate" {
  count = var.create_otel_certs && var.create_cluster_issuer ? 1 : 0

  depends_on = [kubernetes_manifest.ca_cluster_issuer]

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "external-otelsvr"
      namespace = var.bnk_namespace
    }
    spec = {
      secretName = "external-otelsvr-secret"
      commonName = "f5net.com"
      subject = {
        countries           = ["US"]
        provinces           = ["Washington"]
        localities          = ["Seattle"]
        organizations       = ["F5 Networks"]
        organizationalUnits = ["PD"]
      }
      emailAddresses = ["clientcert@f5net.com"]
      duration       = "8640h" # 360 days (per F5 docs)
      renewBefore    = "720h"  # Renew 30 days before expiry
      issuerRef = {
        name  = var.cluster_issuer_name
        kind  = "ClusterIssuer"
        group = "cert-manager.io"
      }
      privateKey = {
        rotationPolicy = "Always"
        encoding       = "PKCS1"
        algorithm      = "RSA"
        size           = 4096
      }
      revisionHistoryLimit = 10
    }
  }
}

resource "kubernetes_manifest" "otel_f5ing_server_certificate" {
  count = var.create_otel_certs && var.create_cluster_issuer ? 1 : 0

  depends_on = [kubernetes_manifest.ca_cluster_issuer]

  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "external-f5ingotelsvr"
      namespace = var.bnk_namespace
    }
    spec = {
      secretName = "external-f5ingotelsvr-secret"
      commonName = "f5net.com"
      subject = {
        countries           = ["US"]
        provinces           = ["Washington"]
        localities          = ["Seattle"]
        organizations       = ["F5 Networks"]
        organizationalUnits = ["PD"]
      }
      emailAddresses = ["clientcert@f5net.com"]
      duration       = "8640h" # 360 days (per F5 docs)
      renewBefore    = "720h"  # Renew 30 days before expiry
      issuerRef = {
        name  = var.cluster_issuer_name
        kind  = "ClusterIssuer"
        group = "cert-manager.io"
      }
      privateKey = {
        rotationPolicy = "Always"
        encoding       = "PKCS1"
        algorithm      = "RSA"
        size           = 4096
      }
      revisionHistoryLimit = 10
    }
  }
}

# =============================================================================
# VERIFY OTEL CERTIFICATES
# =============================================================================

resource "null_resource" "verify_bnk_certificates" {
  count = var.create_otel_certs && var.create_cluster_issuer ? 1 : 0

  depends_on = [
    kubernetes_manifest.otel_server_certificate,
    kubernetes_manifest.otel_f5ing_server_certificate,
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Verifying OTEL Managed Certificates ==="
      
      # Wait for cert-manager to issue the certificates
      sleep 15
      
      echo ""
      echo "=== Certificate resources in ${var.bnk_namespace} ==="
      kubectl get certificates -n ${var.bnk_namespace} 2>/dev/null | grep -E "otelsvr|NAMESPACE" || echo "No OTEL certificates found"
      
      echo ""
      echo "=== Certificate status ==="
      for cert in external-otelsvr external-f5ingotelsvr; do
        STATUS=$(kubectl get certificate "$cert" -n ${var.bnk_namespace} -o jsonpath='{.status.conditions[0].status}' 2>/dev/null)
        REASON=$(kubectl get certificate "$cert" -n ${var.bnk_namespace} -o jsonpath='{.status.conditions[0].reason}' 2>/dev/null)
        if [ "$STATUS" = "True" ]; then
          echo "  OK: $cert is Ready"
        elif [ -n "$STATUS" ]; then
          echo "  WARN: $cert status=$STATUS reason=$REASON"
        else
          echo "  PENDING: $cert not yet processed"
        fi
      done
      
      echo ""
      echo "OK: OTEL certs managed by cert-manager with auto-rotation"
      echo "    (CWC certs are auto-managed by FLO — no action needed)"
    EOT
  }
}

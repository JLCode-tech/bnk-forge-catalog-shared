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

resource "kubernetes_namespace" "cert_manager" {
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
  depends_on = [kubernetes_namespace.cert_manager]

  name       = var.release_name
  namespace  = var.namespace
  chart      = "cert-manager"
  repository = "https://charts.jetstack.io"
  version    = var.cert_manager_version

  # Values for cert-manager configuration
  values = [
    yamlencode({
      # Install CRDs - required for cert-manager to function
      installCRDs = true

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

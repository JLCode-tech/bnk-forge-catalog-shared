# bnk/cneinstance/main.tf
# CNEInstance — BIG-IP Next for Kubernetes GA 2.2
#
# Creates the CNEInstance custom resource which tells FLO to deploy
# ALL BNK components (TMM, CWC, DSSM, Observer, OTEL, RabbitMQ, etc.)
# into the instance namespace.
#
# Uses kubectl apply (not kubernetes_manifest) because:
# - The CNEInstance CRD is installed by FLO, not available at plan time
# - kubernetes_manifest requires CRD at plan time
# - kubectl is available in the celery-worker container
# - No Python or AWS CLI needed — kubectl uses injected kubeconfig

# =============================================================================
# LOCAL VALUES
# =============================================================================

locals {
  # Build the CNEInstance YAML manifest
  cneinstance_manifest = {
    apiVersion = "k8s.f5.com/v1"
    kind       = "CNEInstance"
    metadata = {
      name      = var.instance_name
      namespace = var.instance_namespace
      labels = {
        "app.kubernetes.io/name"       = var.instance_name
        "app.kubernetes.io/component"  = "cne-instance"
        "app.kubernetes.io/managed-by" = "terraform"
        "app.kubernetes.io/version"    = var.manifest_version
      }
    }
    spec = {
      manifestVersion = var.manifest_version
      deploymentSize  = var.deployment_size

      product = {
        type       = "BNK"
        gatewayAPI = true
      }

      registry = {
        uri              = "repo.f5.com"
        imagePullPolicy  = "IfNotPresent"
        imagePullSecrets = [{ name = var.far_secret_name }]
      }

      networkAttachments = [var.external_nad_name, var.internal_nad_name]

      certificate = {
        clusterIssuer = var.cluster_issuer_name
      }
    }
  }
}

# =============================================================================
# WRITE MANIFEST TO FILE
# =============================================================================

resource "local_file" "cneinstance_manifest" {
  filename = "${path.module}/work/cneinstance.yaml"
  content  = yamlencode(local.cneinstance_manifest)
}

# =============================================================================
# CREATE / UPDATE CNEInstance
# =============================================================================

resource "null_resource" "cneinstance" {
  triggers = {
    manifest_hash = sha256(yamlencode(local.cneinstance_manifest))
    name          = var.instance_name
    namespace     = var.instance_namespace
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Creating/Updating CNEInstance ${var.instance_name} ==="

      # Apply the manifest (creates or updates)
      kubectl apply -f ${local_file.cneinstance_manifest.filename} 2>&1

      if [ $? -ne 0 ]; then
        echo "ERROR: Failed to apply CNEInstance manifest"
        echo "Checking if CRD exists..."
        kubectl get crd cneinstances.k8s.f5.com 2>/dev/null || echo "CRD not found — FLO may not be ready"
        exit 1
      fi

      echo "CNEInstance ${var.instance_name} applied successfully"
    EOT
  }

  # Destroy: delete the CNEInstance CR
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "=== Deleting CNEInstance ${self.triggers.name} ==="
      kubectl delete cneinstance ${self.triggers.name} \
        -n ${self.triggers.namespace} \
        --timeout=120s 2>/dev/null || \
      echo "CNEInstance ${self.triggers.name} already deleted or not found"
    EOT
  }

  depends_on = [local_file.cneinstance_manifest]
}

# =============================================================================
# WAIT FOR CNEInstance TO BECOME AVAILABLE
# =============================================================================
# FLO sees the CNEInstance CR and starts deploying components.
# This takes several minutes. We wait for Available=True condition.

resource "null_resource" "wait_for_available" {
  depends_on = [null_resource.cneinstance]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Waiting for CNEInstance ${var.instance_name} to become Available ==="
      echo "This typically takes 3-8 minutes as FLO deploys all BNK components..."

      # Wait up to 10 minutes for Available condition
      TIMEOUT=600
      INTERVAL=15
      ELAPSED=0

      while [ $ELAPSED -lt $TIMEOUT ]; do
        # Get the Available condition
        STATUS=$(kubectl get cneinstance ${var.instance_name} \
          -n ${var.instance_namespace} \
          -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null)

        REASON=$(kubectl get cneinstance ${var.instance_name} \
          -n ${var.instance_namespace} \
          -o jsonpath='{.status.conditions[?(@.type=="Available")].reason}' 2>/dev/null)

        if [ "$STATUS" = "True" ]; then
          echo "CNEInstance ${var.instance_name} is Available!"
          break
        fi

        echo "  Status: $STATUS, Reason: $REASON ($${ELAPSED}s elapsed)"
        sleep $INTERVAL
        ELAPSED=$((ELAPSED + INTERVAL))
      done

      if [ "$STATUS" != "True" ]; then
        echo ""
        echo "WARNING: CNEInstance not yet Available after $${TIMEOUT}s"
        echo "This may be normal for first deployment. Check FLO logs:"
        echo "  kubectl logs -n ${var.instance_namespace} -l app=flo --tail=50"
        echo ""
        echo "Current CNEInstance status:"
        kubectl get cneinstance ${var.instance_name} -n ${var.instance_namespace} -o yaml 2>/dev/null | grep -A5 "conditions:" || true
        # Don't fail — the instance may still be deploying
      fi
    EOT
  }
}

# =============================================================================
# VERIFY PODS ARE RUNNING
# =============================================================================

resource "null_resource" "verify_pods" {
  depends_on = [null_resource.wait_for_available]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Verifying BNK Pods ==="

      echo ""
      echo "--- Pods in ${var.instance_namespace} ---"
      kubectl get pods -n ${var.instance_namespace} -o wide 2>/dev/null

      echo ""
      echo "--- CNEInstance Status ---"
      kubectl get cneinstance ${var.instance_name} -n ${var.instance_namespace} 2>/dev/null

      echo ""
      echo "--- Component Summary ---"
      # Count running pods
      TOTAL=$(kubectl get pods -n ${var.instance_namespace} --no-headers 2>/dev/null | wc -l)
      RUNNING=$(kubectl get pods -n ${var.instance_namespace} --no-headers 2>/dev/null | grep -c "Running" || true)
      COMPLETED=$(kubectl get pods -n ${var.instance_namespace} --no-headers 2>/dev/null | grep -c "Completed" || true)

      echo "Total pods: $TOTAL"
      echo "Running: $RUNNING"
      echo "Completed: $COMPLETED"

      # Check for key components
      echo ""
      echo "--- Key Components ---"
      for component in flo cne-controller tmm cwc dssm observer otel rabbit fluentd; do
        COUNT=$(kubectl get pods -n ${var.instance_namespace} --no-headers 2>/dev/null | grep -c "$component" || true)
        if [ "$COUNT" -gt 0 ]; then
          echo "  OK: $component ($COUNT pods)"
        else
          echo "  MISSING: $component"
        fi
      done

      echo ""
      echo "CNEInstance verification complete"
    EOT
  }
}

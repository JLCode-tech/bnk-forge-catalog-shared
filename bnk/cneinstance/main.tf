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
# KUBECONFIG FOR KUBECTL
# =============================================================================
# Generate a kubeconfig file from the EKS provider data so kubectl works
# in local-exec provisioners.

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
# LOCAL VALUES
# =============================================================================

locals {
  kubectl = "kubectl --kubeconfig ${local_file.kubeconfig.filename}"

  # TMM environment variables — these MUST be set explicitly.
  # FLO does NOT set these from CNEInstance defaults.
  tmm_env = concat(
    [
      { name = "TMM_DEFAULT_MTU", value = tostring(var.tmm_default_mtu) },
      { name = "TMM_IGNORE_GATEWAYS", value = var.tmm_ignore_gateways ? "TRUE" : "FALSE" },
    ],
    var.tmm_extra_env
  )

  # Controller environment variables
  # When cloud_provider is set (e.g. "aws"), inject CLOUD_ENV, CLOUD_PROVIDER,
  # and CLOUD_NETWORK_CONFIGMAP so the CNE controller is cloud-aware.
  cloud_env = var.cloud_provider != "" ? [
    { name = "CLOUD_ENV", value = "true" },
    { name = "CLOUD_PROVIDER", value = var.cloud_provider },
    { name = "CLOUD_NETWORK_CONFIGMAP", value = "cloud-network-mapping" },
  ] : []

  controller_env = concat(
    [
      { name = "TMM_DEFAULT_MTU", value = tostring(var.tmm_default_mtu) },
    ],
    local.cloud_env,
    var.controller_extra_env
  )

  # Optional spec fields that should only appear when set
  storage_class_field = var.storage_class_name != "" ? {
    storageClassName = var.storage_class_name
  } : {}

  # Build the CNEInstance YAML manifest
  # All feature toggles MUST be set explicitly with enabled: true/false.
  # Empty objects {} cause FLO to generate a minimal TMM template missing
  # volume mounts (/var/download), sidecars, and gRPC config setup.
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
    spec = merge({
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

      # --- Deployment mode ---
      # wholeCluster=true + dpu=false → standard Deployment (1 TMM per labeled node)
      # Without wholeCluster, TMM uses TMMReplicas count instead
      wholeCluster = var.whole_cluster

      dpu = {
        enabled = var.dpu_enabled
      }

      # --- Feature toggles ---
      # These MUST be explicitly set. Empty {} objects cause FLO to generate
      # a minimal TMM template missing /var/download volume mounts, sidecars,
      # and proper gRPC config server setup → TMM readiness gates stay False.
      dynamicRouting = {
        enabled = var.dynamic_routing_enabled
      }

      firewallACL = {
        enabled = var.firewall_acl_enabled
      }

      pseudoCNI = {
        enabled = var.pseudo_cni_enabled
      }

      coreCollection = {
        enabled = var.core_collection_enabled
      }

      # AI Intelligent Load Balancing — deploys f5-analyzer pod
      # Required for F5BigAnalyzer CRs (custom/builtin scripts)
      intelligentLB = var.intelligent_lb_enabled

      telemetry = {
        loggingSubsystem = {
          enabled = var.telemetry_logging_enabled
        }
        metricSubsystem = {
          enabled = var.telemetry_metrics_enabled
        }
      }

      # --- Advanced settings ---
      advanced = {
        # envDiscovery validates SR-IOV VFs, hugepages, node labels, etc.
        # Disabled by default: it checks for OVN annotations (k8s.ovn.org/node-primary-ifaddr)
        # which don't exist on AWS VPC CNI clusters, causing false failures.
        envDiscovery = {
          enabled    = var.env_discovery_enabled
          stopOnFail = var.env_discovery_stop_on_fail
        }

        cneController = {
          env = local.controller_env
        }

        tmm = {
          env = local.tmm_env
        }
      }
    }, local.storage_class_field)
  }
}

# =============================================================================
# CLOUD NETWORK MAPPING CONFIGMAP (AWS only)
# =============================================================================
# When cloud_provider is set, the CNE controller expects a ConfigMap mapping
# availability zones to subnet CIDRs/IDs. This tells the controller which
# subnet belongs to which AZ for cloud-aware routing and self-IP assignment.

resource "null_resource" "cloud_network_mapping" {
  count = var.cloud_provider != "" && length(var.cloud_az_subnet_mappings) > 0 ? 1 : 0

  triggers = {
    mappings_hash = sha256(jsonencode(var.cloud_az_subnet_mappings))
    namespace     = var.instance_namespace
    kubeconfig    = local_file.kubeconfig.filename
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Creating cloud-network-mapping ConfigMap ==="
      cat <<'MANIFEST' | ${local.kubectl} apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: cloud-network-mapping
  namespace: ${var.instance_namespace}
data:
  config.yaml: |
    availability_zones:
%{for mapping in var.cloud_az_subnet_mappings~}
      - name: "${mapping.az}"
        subnets:
%{for subnet in mapping.subnets~}
          - cidr: "${subnet.cidr}"
            subnet_id: "${subnet.subnet_id}"
%{endfor~}
%{endfor~}
MANIFEST
      echo "cloud-network-mapping ConfigMap created"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "=== Deleting cloud-network-mapping ConfigMap ==="
      kubectl --kubeconfig ${self.triggers.kubeconfig} delete configmap cloud-network-mapping \
        -n ${self.triggers.namespace} 2>/dev/null || \
      echo "ConfigMap already deleted or not found"
    EOT
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
    kubeconfig    = local_file.kubeconfig.filename
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Creating/Updating CNEInstance ${var.instance_name} ==="

      # Apply the manifest (creates or updates)
      ${local.kubectl} apply -f ${local_file.cneinstance_manifest.filename} 2>&1

      if [ $? -ne 0 ]; then
        echo "ERROR: Failed to apply CNEInstance manifest"
        echo "Checking if CRD exists..."
        ${local.kubectl} get crd cneinstances.k8s.f5.com 2>/dev/null || echo "CRD not found — FLO may not be ready"
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
      kubectl --kubeconfig ${self.triggers.kubeconfig} delete cneinstance ${self.triggers.name} \
        -n ${self.triggers.namespace} \
        --timeout=120s 2>/dev/null || \
      echo "CNEInstance ${self.triggers.name} already deleted or not found"
    EOT
  }

  depends_on = [
    local_file.cneinstance_manifest,
    null_resource.cloud_network_mapping,
  ]
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
        STATUS=$(${local.kubectl} get cneinstance ${var.instance_name} \
          -n ${var.instance_namespace} \
          -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null)

        REASON=$(${local.kubectl} get cneinstance ${var.instance_name} \
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
        ${local.kubectl} get cneinstance ${var.instance_name} -n ${var.instance_namespace} -o yaml 2>/dev/null | grep -A5 "conditions:" || true
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

      KUBECTL="${local.kubectl}"

      echo ""
      echo "--- Pods in ${var.instance_namespace} ---"
      $KUBECTL get pods -n ${var.instance_namespace} -o wide 2>/dev/null

      echo ""
      echo "--- CNEInstance Status ---"
      $KUBECTL get cneinstance ${var.instance_name} -n ${var.instance_namespace} 2>/dev/null

      echo ""
      echo "--- Component Summary ---"
      # Count running pods
      TOTAL=$($KUBECTL get pods -n ${var.instance_namespace} --no-headers 2>/dev/null | wc -l)
      RUNNING=$($KUBECTL get pods -n ${var.instance_namespace} --no-headers 2>/dev/null | grep -c "Running" || true)
      COMPLETED=$($KUBECTL get pods -n ${var.instance_namespace} --no-headers 2>/dev/null | grep -c "Completed" || true)

      echo "Total pods: $TOTAL"
      echo "Running: $RUNNING"
      echo "Completed: $COMPLETED"

      # Check for key components
      echo ""
      echo "--- Key Components ---"
      for component in flo cne-controller tmm cwc dssm observer otel rabbit fluentd; do
        COUNT=$($KUBECTL get pods -n ${var.instance_namespace} --no-headers 2>/dev/null | grep -c "$component" || true)
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

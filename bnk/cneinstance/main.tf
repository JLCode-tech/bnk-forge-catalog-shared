# infrastructure-modules/bnk/cneinstance/main.tf
# CneInstance - CNE Instance Configuration
# Uses Python kubernetes client to apply CRD (avoids terraform kubernetes_manifest schema issues)

# =============================================================================
# LOCAL VALUES
# =============================================================================

locals {
  labels = merge(var.common_labels, {
    "app.kubernetes.io/name"       = var.instance_name
    "app.kubernetes.io/component"  = "cne-instance"
    "app.kubernetes.io/managed-by" = "terraform"
  })

  # Build the CNEInstance manifest
  cneinstance_manifest = {
    apiVersion = "k8s.f5.com/v1"
    kind       = "CNEInstance"
    metadata = {
      name        = var.instance_name
      namespace   = var.instance_namespace
      labels      = local.labels
      annotations = var.annotations
    }
    spec = merge(
      {
        instanceType = var.instance_config.instance_type
        replicas     = var.instance_config.replicas
      },
      length(var.resource_limits) > 0 ? {
        resources = {
          requests = {
            cpu    = var.resource_limits.cpu_request
            memory = var.resource_limits.memory_request
          }
          limits = {
            cpu    = var.resource_limits.cpu_limit
            memory = var.resource_limits.memory_limit
          }
        }
      } : {},
      length(var.instance_config.affinity) > 0 ? {
        affinity = var.instance_config.affinity
      } : {}
    )
  }

  # Python script to apply the CNEInstance using kubernetes client
  apply_script = <<-PYTHON
import json
import sys
from kubernetes import client, config
from kubernetes.client.rest import ApiException

manifest = json.loads(sys.argv[1])

# Load kubeconfig from environment (set by tofu)
config.load_kube_config()

api = client.CustomObjectsApi()

group = "k8s.f5.com"
version = "v1"
plural = "cneinstances"
namespace = manifest["metadata"]["namespace"]
name = manifest["metadata"]["name"]

try:
    # Try to get existing resource
    existing = api.get_namespaced_custom_object(group, version, namespace, plural, name)
    # Update existing
    manifest["metadata"]["resourceVersion"] = existing["metadata"]["resourceVersion"]
    result = api.replace_namespaced_custom_object(group, version, namespace, plural, name, manifest)
    print(f"Updated CNEInstance {name} in namespace {namespace}")
except ApiException as e:
    if e.status == 404:
        # Create new
        result = api.create_namespaced_custom_object(group, version, namespace, plural, manifest)
        print(f"Created CNEInstance {name} in namespace {namespace}")
    else:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
PYTHON

  delete_script = <<-PYTHON
import sys
from kubernetes import client, config
from kubernetes.client.rest import ApiException

namespace = sys.argv[1]
name = sys.argv[2]

config.load_kube_config()

api = client.CustomObjectsApi()

try:
    api.delete_namespaced_custom_object("k8s.f5.com", "v1", namespace, "cneinstances", name)
    print(f"Deleted CNEInstance {name} from namespace {namespace}")
except ApiException as e:
    if e.status == 404:
        print(f"CNEInstance {name} not found - already deleted")
    else:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
PYTHON
}

# =============================================================================
# CNE INSTANCE - Using Python kubernetes client
# =============================================================================

resource "null_resource" "cneinstance" {
  depends_on = [var.flo_ready]

  triggers = {
    manifest_hash = sha256(jsonencode(local.cneinstance_manifest))
    name          = var.instance_name
    namespace     = var.instance_namespace
  }

  provisioner "local-exec" {
    command = "python3 -c '${replace(local.apply_script, "'", "\\'")}' '${jsonencode(local.cneinstance_manifest)}'"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "python3 -c '${replace(local.delete_script, "'", "\\'")}' '${self.triggers.namespace}' '${self.triggers.name}'"
  }
}

# =============================================================================
# VERIFICATION
# =============================================================================

resource "time_sleep" "wait_for_instance" {
  depends_on = [null_resource.cneinstance]

  create_duration = "10s"
}

resource "null_resource" "verify_instance" {
  depends_on = [time_sleep.wait_for_instance]

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Verifying CNEInstance ${var.instance_name} ==="
      python3 -c "
from kubernetes import client, config
config.load_kube_config()
api = client.CustomObjectsApi()
result = api.get_namespaced_custom_object('k8s.f5.com', 'v1', '${var.instance_namespace}', 'cneinstances', '${var.instance_name}')
print(f'CNEInstance {result[\"metadata\"][\"name\"]} found in namespace {result[\"metadata\"][\"namespace\"]}')
print(f'Status: {result.get(\"status\", \"pending\")}')
"
      echo "✓ CNEInstance verification complete"
    EOT
  }
}

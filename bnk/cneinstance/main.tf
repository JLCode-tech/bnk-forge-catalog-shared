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

  # Kubeconfig for Python to use
  # Uses data sources from bnk_forge_providers.tf (injected by BNK-Forge)
  kubeconfig = {
    apiVersion = "v1"
    kind       = "Config"
    clusters = [{
      name = var.cluster_name
      cluster = {
        server                     = data.aws_eks_cluster.cluster.endpoint
        certificate-authority-data = data.aws_eks_cluster.cluster.certificate_authority[0].data
      }
    }]
    users = [{
      name = "terraform"
      user = {
        token = data.aws_eks_cluster_auth.cluster.token
      }
    }]
    contexts = [{
      name = "default"
      context = {
        cluster = var.cluster_name
        user    = "terraform"
      }
    }]
    current-context = "default"
  }
}

# =============================================================================
# CNE INSTANCE - Using Python kubernetes client with dynamic kubeconfig
# =============================================================================

resource "null_resource" "cneinstance" {
  depends_on = [var.flo_ready]

  triggers = {
    manifest_hash = sha256(jsonencode(local.cneinstance_manifest))
    manifest_json = jsonencode(local.cneinstance_manifest)
    name          = var.instance_name
    namespace     = var.instance_namespace
    cluster_name  = var.cluster_name
  }

  provisioner "local-exec" {
    command = <<-EOT
python3 << 'PYEOF'
import json
import os
import tempfile
from kubernetes import client, config
from kubernetes.client.rest import ApiException

manifest = json.loads('''${jsonencode(local.cneinstance_manifest)}''')
kubeconfig = json.loads('''${jsonencode(local.kubeconfig)}''')

# Write temporary kubeconfig
with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as f:
    import yaml
    yaml.dump(kubeconfig, f)
    kubeconfig_path = f.name

try:
    config.load_kube_config(config_file=kubeconfig_path)
    api = client.CustomObjectsApi()

    group = "k8s.f5.com"
    version = "v1"
    plural = "cneinstances"
    namespace = manifest["metadata"]["namespace"]
    name = manifest["metadata"]["name"]

    try:
        existing = api.get_namespaced_custom_object(group, version, namespace, plural, name)
        manifest["metadata"]["resourceVersion"] = existing["metadata"]["resourceVersion"]
        result = api.replace_namespaced_custom_object(group, version, namespace, plural, name, manifest)
        print(f"Updated CNEInstance {name} in namespace {namespace}")
    except ApiException as e:
        if e.status == 404:
            result = api.create_namespaced_custom_object(group, version, namespace, plural, manifest)
            print(f"Created CNEInstance {name} in namespace {namespace}")
        else:
            raise
finally:
    os.unlink(kubeconfig_path)
PYEOF
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
python3 << 'PYEOF'
import os
import tempfile
from kubernetes import client, config
from kubernetes.client.rest import ApiException

# For destroy, we need to re-generate kubeconfig from EKS
import subprocess
import json

namespace = "${self.triggers.namespace}"
name = "${self.triggers.name}"
cluster_name = "${self.triggers.cluster_name}"

# Get cluster info via AWS CLI
result = subprocess.run(
    ["aws", "eks", "describe-cluster", "--name", cluster_name, "--output", "json"],
    capture_output=True, text=True
)
if result.returncode != 0:
    print(f"Warning: Could not get cluster info: {result.stderr}")
    print(f"CNEInstance {name} may need manual cleanup")
    exit(0)

cluster_info = json.loads(result.stdout)["cluster"]

# Get token
token_result = subprocess.run(
    ["aws", "eks", "get-token", "--cluster-name", cluster_name, "--output", "json"],
    capture_output=True, text=True
)
if token_result.returncode != 0:
    print(f"Warning: Could not get token: {token_result.stderr}")
    exit(0)

token = json.loads(token_result.stdout)["status"]["token"]

kubeconfig = {
    "apiVersion": "v1",
    "kind": "Config",
    "clusters": [{
        "name": cluster_name,
        "cluster": {
            "server": cluster_info["endpoint"],
            "certificate-authority-data": cluster_info["certificateAuthority"]["data"]
        }
    }],
    "users": [{"name": "terraform", "user": {"token": token}}],
    "contexts": [{"name": "default", "context": {"cluster": cluster_name, "user": "terraform"}}],
    "current-context": "default"
}

with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as f:
    import yaml
    yaml.dump(kubeconfig, f)
    kubeconfig_path = f.name

try:
    config.load_kube_config(config_file=kubeconfig_path)
    api = client.CustomObjectsApi()
    api.delete_namespaced_custom_object("k8s.f5.com", "v1", namespace, "cneinstances", name)
    print(f"Deleted CNEInstance {name} from namespace {namespace}")
except ApiException as e:
    if e.status == 404:
        print(f"CNEInstance {name} not found - already deleted")
    else:
        raise
finally:
    os.unlink(kubeconfig_path)
PYEOF
    EOT
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
python3 << 'PYEOF'
import json
import os
import tempfile
from kubernetes import client, config
import yaml

kubeconfig = json.loads('''${jsonencode(local.kubeconfig)}''')

with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as f:
    yaml.dump(kubeconfig, f)
    kubeconfig_path = f.name

try:
    config.load_kube_config(config_file=kubeconfig_path)
    api = client.CustomObjectsApi()
    result = api.get_namespaced_custom_object('k8s.f5.com', 'v1', '${var.instance_namespace}', 'cneinstances', '${var.instance_name}')
    print(f"CNEInstance {result['metadata']['name']} found in namespace {result['metadata']['namespace']}")
    print(f"Status: {result.get('status', 'pending')}")
finally:
    os.unlink(kubeconfig_path)
PYEOF
      echo "✓ CNEInstance verification complete"
    EOT
  }
}

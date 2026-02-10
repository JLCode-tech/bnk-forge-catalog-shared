# infrastructure-modules/bnk/cneinstance/main.tf
# CNEInstance - BIG-IP Next for Kubernetes GA 2.2
# Creates CNEInstance custom resource using Python kubernetes client

# =============================================================================
# LOCAL VALUES
# =============================================================================

locals {
  labels = merge(var.common_labels, {
    "app.kubernetes.io/name"       = var.instance_name
    "app.kubernetes.io/component"  = "cne-instance"
    "app.kubernetes.io/managed-by" = "terraform"
    "app.kubernetes.io/version"    = var.manifest_version
  })

  # Build the CNEInstance manifest for BNK GA 2.2
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
        # Required fields
        manifestVersion = var.manifest_version
        deploymentSize  = var.deployment_size

        # Product configuration
        product = {
          type       = var.product_type
          gatewayAPI = var.gateway_api_enabled
        }

        # Registry configuration
        registry = merge(
          {
            uri             = var.registry_uri
            imagePullPolicy = var.image_pull_policy
          },
          length(var.image_pull_secrets) > 0 ? {
            imagePullSecrets = [for secret in var.image_pull_secrets : { name = secret }]
          } : {}
        )

        # Network attachments (from network-setup module outputs)
        networkAttachments = [var.external_nad_name, var.internal_nad_name]

        # Certificate configuration
        certificate = var.cluster_issuer != "" ? {
          clusterIssuer = var.cluster_issuer
        } : {}
      },
      # Advanced configuration
      var.demo_mode ? {
        advanced = {
          demoMode = {
            enabled = true
          }
        }
      } : {},
      var.advanced_config.maintenance_mode ? {
        advanced = merge(
          try(var.advanced_config.maintenance_mode, false) ? {
            maintenanceMode = {
              enabled = true
            }
          } : {}
        )
      } : {}
    )
  }

  # Kubeconfig for Python to use (from injected provider data sources)
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
# CNE INSTANCE - Using Python kubernetes client
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

  create_duration = "30s"
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
    status = result.get('status', {})
    print(f"Phase: {status.get('phase', 'Unknown')}")
    print(f"Ready: {status.get('ready', 'Unknown')}")
finally:
    os.unlink(kubeconfig_path)
PYEOF
      echo "✓ CNEInstance verification complete"
    EOT
  }
}

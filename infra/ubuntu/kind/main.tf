# infra/ubuntu/kind/main.tf
# Provisions a kind cluster on Ubuntu for BNK development/testing

locals {
  kubeconfig_path = "${path.module}/work/kubeconfig"
}

# Generate kind config with the requested number of workers
resource "local_file" "kind_config" {
  filename = "${path.module}/kind-config.yaml"
  content = yamlencode({
    kind       = "Cluster"
    apiVersion = "kind.x-k8s.io/v1alpha4"
    nodes = concat(
      [{ role = "control-plane" }],
      [for i in range(var.worker_nodes) : { role = "worker" }]
    )
  })
}

resource "terraform_data" "kind_cluster" {
  depends_on = [local_file.kind_config]

  input = {
    cluster_name       = var.cluster_name
    kubernetes_version = var.kubernetes_version
    worker_nodes       = var.worker_nodes
    kubeconfig_path    = local.kubeconfig_path
  }

  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p "$(dirname '${local.kubeconfig_path}')" && \
      kind create cluster \
        --name ${var.cluster_name} \
        --image kindest/node:v${var.kubernetes_version} \
        --config ${path.module}/kind-config.yaml \
        --kubeconfig ${local.kubeconfig_path}
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kind delete cluster --name ${self.input.cluster_name} || true"
  }
}

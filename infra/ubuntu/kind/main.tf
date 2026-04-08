# infra/ubuntu/kind/main.tf
# Provisions a kind cluster on Ubuntu for BNK development/testing

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

resource "null_resource" "kind_cluster" {
  depends_on = [local_file.kind_config]

  triggers = {
    cluster_name       = var.cluster_name
    kubernetes_version = var.kubernetes_version
    worker_nodes       = var.worker_nodes
  }

  provisioner "local-exec" {
    command = <<-EOT
      mkdir -p ${path.module}/work && \
      kind create cluster \
        --name ${var.cluster_name} \
        --image kindest/node:v${var.kubernetes_version} \
        --config ${path.module}/kind-config.yaml \
        --kubeconfig ${path.module}/work/kubeconfig
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "kind delete cluster --name ${self.triggers.cluster_name} || true"
  }
}

# Read the kubeconfig after kind creates it.
# null_resource.kind_cluster must complete first (explicit dependency).
data "local_file" "kubeconfig" {
  depends_on = [null_resource.kind_cluster]
  filename   = "${path.module}/work/kubeconfig"
}

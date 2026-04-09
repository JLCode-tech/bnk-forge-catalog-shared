locals {
  remote_enabled         = trimspace(var.ssh_host) != ""
  remote_workspace_dir   = "/tmp/bnk-forge-kind-${var.cluster_name}"
  remote_kubeconfig_dir  = "/tmp/bnk-forge-kind-kubeconfig-${var.cluster_name}"
  remote_kubeconfig_path = "${local.remote_kubeconfig_dir}/config"
  local_artifact_dir     = "${path.module}/work/${var.cluster_name}"
  local_kubeconfig_path  = "${local.local_artifact_dir}/kubeconfig"
  local_kind_config_path = "${path.module}/work/${var.cluster_name}/kind-config.yaml"
  kind_node_image        = "kindest/node:v${var.kubernetes_version}"
}

resource "terraform_data" "validate_remote_inputs" {
  lifecycle {
    precondition {
      condition     = local.remote_enabled
      error_message = "infra/ubuntu/kind now requires ssh_host. This slice is remote-bootstrap only; local runner cluster creation is no longer claimed by this module."
    }

    precondition {
      condition     = trimspace(var.ssh_user) != ""
      error_message = "ssh_user must be set when bootstrapping a remote Ubuntu host."
    }

    precondition {
      condition     = trimspace(var.ssh_private_key_path) != ""
      error_message = "ssh_private_key_path must point to the SSH private key used for remote bootstrap."
    }
  }
}

resource "local_file" "kind_config" {
  depends_on = [terraform_data.validate_remote_inputs]

  filename = local.local_kind_config_path
  content = yamlencode({
    kind       = "Cluster"
    apiVersion = "kind.x-k8s.io/v1alpha4"
    nodes = concat(
      [{ role = "control-plane" }],
      [for _ in range(var.worker_nodes) : { role = "worker" }]
    )
  })
}

resource "terraform_data" "kind_cluster" {
  depends_on = [local_file.kind_config]

  triggers_replace = {
    cluster_name           = var.cluster_name
    kubernetes_version     = var.kubernetes_version
    worker_nodes           = tostring(var.worker_nodes)
    ssh_host               = var.ssh_host
    ssh_user               = var.ssh_user
    ssh_private_key_path   = var.ssh_private_key_path
    ssh_timeout            = var.ssh_timeout
    remote_workspace_dir   = local.remote_workspace_dir
    remote_kubeconfig_dir  = local.remote_kubeconfig_dir
    local_kubeconfig_path  = local.local_kubeconfig_path
    local_kind_config_path = local.local_kind_config_path
    kind_config_sha256     = sha256(local_file.kind_config.content)
  }

  provisioner "local-exec" {
    command = "mkdir -p '${local.local_artifact_dir}'"
  }

  provisioner "file" {
    connection {
      type        = "ssh"
      host        = var.ssh_host
      user        = var.ssh_user
      private_key = file(var.ssh_private_key_path)
      timeout     = var.ssh_timeout
    }

    source      = local_file.kind_config.filename
    destination = "${local.remote_workspace_dir}/kind-config.yaml"
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = var.ssh_host
      user        = var.ssh_user
      private_key = file(var.ssh_private_key_path)
      timeout     = var.ssh_timeout
    }

    inline = [
      "set -euo pipefail",
      "export DEBIAN_FRONTEND=noninteractive",
      "if command -v sudo >/dev/null 2>&1; then SUDO='sudo'; else SUDO=''; fi",
      "$${SUDO} apt-get update -y",
      "$${SUDO} apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release software-properties-common",
      "if ! command -v docker >/dev/null 2>&1; then curl -fsSL https://get.docker.com | sh; fi",
      "$${SUDO} systemctl enable docker",
      "$${SUDO} systemctl start docker",
      "$${SUDO} usermod -aG docker ${var.ssh_user} || true",
      "if ! command -v kind >/dev/null 2>&1; then curl -fsSL https://kind.sigs.k8s.io/dl/${var.kind_version}/kind-linux-amd64 -o /tmp/kind && chmod +x /tmp/kind && $${SUDO} mv /tmp/kind /usr/local/bin/kind; fi",
      "if ! command -v kubectl >/dev/null 2>&1; then curl -fsSL https://dl.k8s.io/release/${var.kubectl_version}/bin/linux/amd64/kubectl -o /tmp/kubectl && chmod +x /tmp/kubectl && $${SUDO} mv /tmp/kubectl /usr/local/bin/kubectl; fi",
      "docker --version >/dev/null 2>&1 || { echo 'Docker installation failed or is not executable'; exit 1; }",
      "kind --version >/dev/null 2>&1 || { echo 'kind installation failed or is not executable'; exit 1; }",
      "kubectl version --client >/dev/null 2>&1 || { echo 'kubectl installation failed or is not executable'; exit 1; }",
      "$${SUDO} mkdir -p ${local.remote_workspace_dir} ${local.remote_kubeconfig_dir}",
      "$${SUDO} chown -R ${var.ssh_user}:${var.ssh_user} ${local.remote_workspace_dir} ${local.remote_kubeconfig_dir}",
      "if kind get clusters | grep -Fx '${var.cluster_name}' >/dev/null 2>&1; then kind delete cluster --name '${var.cluster_name}'; fi",
      "KUBECONFIG='${local.remote_kubeconfig_path}' kind create cluster --name '${var.cluster_name}' --image '${local.kind_node_image}' --config '${local.remote_workspace_dir}/kind-config.yaml' --kubeconfig '${local.remote_kubeconfig_path}'",
      "kubectl --kubeconfig '${local.remote_kubeconfig_path}' cluster-info",
      "kubectl --kubeconfig '${local.remote_kubeconfig_path}' get nodes -o wide",
    ]
  }

  provisioner "local-exec" {
    command = "scp -i '${var.ssh_private_key_path}' -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null '${var.ssh_user}@${var.ssh_host}:${local.remote_kubeconfig_path}' '${local.local_kubeconfig_path}'"
  }

  provisioner "remote-exec" {
    when = destroy

    connection {
      type        = "ssh"
      host        = self.triggers_replace.ssh_host
      user        = self.triggers_replace.ssh_user
      private_key = file(self.triggers_replace.ssh_private_key_path)
      timeout     = self.triggers_replace.ssh_timeout
    }

    inline = [
      "set -e",
      "if command -v kind >/dev/null 2>&1; then kind delete cluster --name '${self.triggers_replace.cluster_name}' || true; fi",
      "rm -rf '${self.triggers_replace.remote_workspace_dir}' '${self.triggers_replace.remote_kubeconfig_dir}' || true",
    ]
  }

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f '${self.triggers_replace.local_kubeconfig_path}' '${self.triggers_replace.local_kind_config_path}' || true"
  }
}

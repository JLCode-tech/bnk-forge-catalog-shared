variable "cluster_name" {
  description = "Name of the kind cluster created on the remote Ubuntu host"
  type        = string
  default     = "bnk-dev"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the remote kind node image"
  type        = string
  default     = "1.29.2"
}

variable "worker_nodes" {
  description = "Number of kind worker nodes to create on the remote host"
  type        = number
  default     = 2

  validation {
    condition     = var.worker_nodes >= 0
    error_message = "worker_nodes must be zero or greater."
  }
}

variable "ssh_host" {
  description = "SSH host or IP for the remote Ubuntu machine to bootstrap"
  type        = string
}

variable "ssh_user" {
  description = "SSH user on the remote Ubuntu machine"
  type        = string
  default     = "ubuntu"
}

variable "ssh_private_key_path" {
  description = "Path on the runner to the SSH private key used for remote bootstrap"
  type        = string

  validation {
    condition     = trimspace(var.ssh_private_key_path) != ""
    error_message = "ssh_private_key_path must not be empty."
  }
}

variable "ssh_timeout" {
  description = "SSH connection timeout for remote bootstrap operations"
  type        = string
  default     = "10m"
}

variable "kind_version" {
  description = "kind release to install on the remote host when kind is absent"
  type        = string
  default     = "v0.23.0"
}

variable "kubectl_version" {
  description = "kubectl release to install on the remote host when kubectl is absent"
  type        = string
  default     = "v1.29.2"
}

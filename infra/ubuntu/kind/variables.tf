variable "cluster_name" {
  description = "Name of the kind cluster"
  type        = string
  default     = "bnk-dev"
}

variable "kubernetes_version" {
  description = "Kubernetes version for kind node image"
  type        = string
  default     = "1.29.2"
}

variable "worker_nodes" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

variable "ssh_host" {
  description = "SSH host for remote Ubuntu machine (empty = local)"
  type        = string
  default     = ""
}

variable "ssh_user" {
  description = "SSH user"
  type        = string
  default     = "ubuntu"
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key"
  type        = string
  default     = ""
}

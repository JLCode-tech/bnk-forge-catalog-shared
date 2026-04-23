# variables.tf - High Performance Nodes Module Variables

# Dependencies from other modules
variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "vpc_security_group_id" {
  description = "ID of the VPC security group"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "key_pair_name" {
  description = "Name of the EC2 key pair"
  type        = string
}

# Security module IAM role references
variable "nodegroup_role_arn" {
  description = "ARN of the nodegroup IAM role from security module"
  type        = string
}

variable "nodegroup_role_name" {
  description = "Name of the nodegroup IAM role from security module"
  type        = string
}

# Project configuration
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS region"
  type        = string
}

# Node configuration
variable "instance_type" {
  description = "EC2 instance type for high-performance nodes"
  type        = string
  default     = "c5n.large"
}

variable "node_count" {
  description = "Number of high-performance nodes"
  type        = number
  default     = 2
}

variable "capacity_type" {
  description = "Capacity type for the node group"
  type        = string
  default     = "ON_DEMAND"
  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.capacity_type)
    error_message = "Capacity type must be either ON_DEMAND or SPOT."
  }
}

variable "node_volume_size" {
  description = "Size of the EBS volume for nodes (GB)"
  type        = number
  default     = 50
}

# Performance configuration
variable "cpu_manager_policy" {
  description = "CPU manager policy for kubelet"
  type        = string
  default     = "static"
  validation {
    condition     = contains(["none", "static"], var.cpu_manager_policy)
    error_message = "CPU manager policy must be 'none' or 'static'."
  }
}

variable "topology_manager_policy" {
  description = "Topology manager policy for kubelet"
  type        = string
  default     = "best-effort"
  validation {
    condition     = contains(["none", "best-effort", "restricted", "single-numa-node"], var.topology_manager_policy)
    error_message = "Topology manager policy must be one of: none, best-effort, restricted, single-numa-node."
  }
}

variable "hugepages_2mi" {
  description = "Number of 2Mi hugepages to allocate"
  type        = number
  default     = 4096
}

variable "hugepages_1gi" {
  description = "Number of 1Gi hugepages to allocate"
  type        = number
  default     = 2
}

# F5 BNK (BIG-IP Next for Kubernetes) configuration
# Per F5 docs: https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/
variable "f5_bnk_enabled" {
  description = "Enable F5 BNK (BIG-IP Next for Kubernetes) specific configurations including TMM node labels, taints, and SR-IOV device plugin"
  type        = bool
  default     = true
}

variable "f5_tmm_cpu_cores" {
  description = "Number of CPU cores for F5 TMM"
  type        = number
  default     = 2
}

variable "f5_numa_node" {
  description = "NUMA node for F5 TMM"
  type        = number
  default     = 0
}

# Taint configuration
variable "enable_taints" {
  description = "Enable taints on high-performance nodes"
  type        = bool
  default     = true
}

variable "tmm_node_count" {
  description = "Number of nodes to dedicate for TMM (tainted with dpu=true:NoSchedule and labeled app=f5-tmm). Remaining nodes stay untainted for BNK control plane pods. Set to 0 to not taint any nodes for TMM."
  type        = number
  default     = 1
  validation {
    condition     = var.tmm_node_count >= 0
    error_message = "tmm_node_count must be >= 0."
  }
}

# Container configuration
variable "ecr_registry" {
  description = "ECR registry URL for container images"
  type        = string
}

variable "multus_container_version" {
  description = "Version tag for multus IP manager container"
  type        = string
  default     = "v1.1.0"
}

variable "eni_attachment_manager_role_arn" {
  description = "ARN of the ENI attachment manager IAM role from security module"
  type        = string
  default     = null
}

variable "kubeconfig_path" {
  description = "Path to kubeconfig used by local-exec provisioners that patch in-cluster resources (e.g. the default aws-node DS)."
  type        = string
  default     = "~/.kube/config"
}

variable "vpc_cni_image" {
  description = <<-EOT
    Full image reference for the VPC CNI (aws-node) container on HP nodes.
    Must match the image/version used by the default kube-system/aws-node
    DS so behavior is consistent across node types. The HP variant is
    configured at this module's aws-node-hp-daemonset.yaml.
  EOT
  type        = string
  default     = "602401143452.dkr.ecr.ap-southeast-2.amazonaws.com/amazon-k8s-cni:v1.18.5"
}

variable "vpc_cni_image_tag" {
  description = "Version tag value reported via the VPC_CNI_VERSION env on aws-node-hp (matches vpc_cni_image tag)."
  type        = string
  default     = "v1.18.5"
}

variable "hugepages_2mb_count" {
  description = <<-EOT
    Number of 2MB hugepages to allocate per HP node. Applied at runtime by
    the hugepages-setup init container on the eni-attachment-manager DS.
    Boot-time persistence (GRUB drop-in + systemd service) is handled
    separately in node userdata — see compact_userdata.sh.
  EOT
  type        = number
  default     = 1024
}
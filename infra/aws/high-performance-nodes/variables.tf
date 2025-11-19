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

# F5 SPK specific configuration
variable "f5_spk_enabled" {
  description = "Enable F5 SPK specific configurations"
  type        = bool
  default     = false
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
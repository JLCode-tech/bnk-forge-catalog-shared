variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
}

variable "cluster_name" {
  description = "Name for the AKS cluster"
  type        = string
}

variable "location" {
  description = "Azure region (e.g., australiaeast, eastus)"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster"
  type        = string
  default     = "1.29"
}

variable "node_count" {
  description = "Number of nodes in the default node pool"
  type        = number
  default     = 2
}

variable "vm_size" {
  description = "Azure VM size for worker nodes"
  type        = string
  default     = "Standard_D4s_v3"
}

variable "dns_prefix" {
  description = "DNS prefix for the AKS cluster"
  type        = string
  default     = ""
}

variable "network_plugin" {
  description = "Network plugin for AKS (azure or kubenet)"
  type        = string
  default     = "azure"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

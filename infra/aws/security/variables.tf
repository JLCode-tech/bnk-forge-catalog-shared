# infrastructure-modules/foundation/security/variables.tf
# Input variables for security module

# =============================================================================
# PROJECT VARIABLES
# =============================================================================

variable "project_name" {
  description = "Name of the project - used for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# =============================================================================
# AWS CONFIGURATION
# =============================================================================

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
}

variable "aws_profile" {
  description = "AWS profile for CLI operations"
  type        = string
}

# =============================================================================
# VPC DEPENDENCY VARIABLES (from VPC module outputs)
# =============================================================================

variable "vpc_id" {
  description = "ID of the VPC where security resources will be created"
  type        = string
}

variable "vpc_cidr_block" {
  description = "CIDR block of the VPC for internal traffic rules"
  type        = string
}

variable "public_subnet_id" {
  description = "ID of the public subnet for jumphost placement"
  type        = string
}

# =============================================================================
# SECURITY CONFIGURATION
# =============================================================================

variable "user_ip" {
  description = "Your public IP address in CIDR format (e.g., 203.123.45.67/32) for SSH access restriction. Required if deploy_jumphost is true."
  type        = string
  default     = "10.0.0.1/32" # Placeholder - override with your actual IP if deploying jumphost

  validation {
    condition     = can(regex("^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}/32$", var.user_ip))
    error_message = "The user_ip must be in CIDR format with /32 suffix (e.g., 203.123.45.67/32)."
  }
}

# =============================================================================
# SSH KEY CONFIGURATION
# =============================================================================

variable "ssh_key_algorithm" {
  description = "Algorithm for SSH key generation"
  type        = string
  default     = "RSA"

  validation {
    condition     = contains(["RSA", "ECDSA", "ED25519"], var.ssh_key_algorithm)
    error_message = "SSH key algorithm must be one of: RSA, ECDSA, ED25519."
  }
}

variable "ssh_key_rsa_bits" {
  description = "Number of bits for RSA SSH key (ignored for other algorithms)"
  type        = number
  default     = 4096

  validation {
    condition     = var.ssh_key_rsa_bits >= 2048 && var.ssh_key_rsa_bits <= 8192
    error_message = "RSA key size must be between 2048 and 8192 bits."
  }
}

# =============================================================================
# JUMPHOST CONFIGURATION
# =============================================================================

variable "jumphost_instance_type" {
  description = "EC2 instance type for jumphost"
  type        = string
  default     = "t3.medium"
}

variable "jumphost_volume_size" {
  description = "Root volume size for jumphost (GB)"
  type        = number
  default     = 20

  validation {
    condition     = var.jumphost_volume_size >= 8 && var.jumphost_volume_size <= 100
    error_message = "Jumphost volume size must be between 8 and 100 GB."
  }
}

variable "enable_jumphost_backup" {
  description = "Enable backup jumphost instance (for production environments)"
  type        = bool
  default     = false
}

# =============================================================================
# KUBERNETES TOOLING VERSIONS
# =============================================================================

variable "kubectl_version" {
  description = "Version of kubectl to install (should match EKS version)"
  type        = string
  default     = "1.30.0"
}

variable "kubectl_release_date" {
  description = "Release date for kubectl version (AWS EKS format: YYYY-MM-DD)"
  type        = string
  default     = "2024-05-12"

  validation {
    condition     = can(regex("^\\d{4}-\\d{2}-\\d{2}$", var.kubectl_release_date))
    error_message = "kubectl_release_date must be in YYYY-MM-DD format."
  }
}

# =============================================================================
# IAM CONFIGURATION
# =============================================================================

variable "enable_enhanced_node_permissions" {
  description = "Enable enhanced permissions for node groups (ENI management, SSM)"
  type        = bool
  default     = true
}

variable "enable_f5_bnk_roles" {
  description = "Enable F5 BIG-IP Next service account roles (for future F5 module)"
  type        = bool
  default     = false
}

# =============================================================================
# OIDC PROVIDER CONFIGURATION (for service account roles)
# =============================================================================

variable "create_oidc_provider" {
  description = "Create OIDC provider for service account roles (requires EKS cluster)"
  type        = bool
  default     = false
}

variable "eks_oidc_issuer_url" {
  description = "EKS cluster OIDC issuer URL (required if create_oidc_provider is true)"
  type        = string
  default     = ""
}

# EKS cluster configuration (for OIDC provider automation)
variable "cluster_name" {
  description = "Name of the EKS cluster (for automated OIDC provider setup)"
  type        = string
  default     = ""
}

# =============================================================================
# OPERATIONAL CONFIGURATION
# =============================================================================

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring for jumphost"
  type        = bool
  default     = false
}
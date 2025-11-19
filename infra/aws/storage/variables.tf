# infrastructure-modules/foundation/storage/variables.tf
# Variables for the storage module - following exact DRY patterns from security/EKS modules

# =============================================================================
# PROJECT VARIABLES (exactly matching security/EKS modules)
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
# AWS CONFIGURATION (exactly matching security/EKS modules)
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
# SECURITY CONFIGURATION (exactly matching security/EKS modules)
# =============================================================================

variable "user_ip" {
  description = "Your public IP address in CIDR format (e.g., 203.123.45.67/32) for security restrictions"
  type        = string
  
  validation {
    condition     = can(regex("^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}/32$", var.user_ip))
    error_message = "The user_ip must be in CIDR format with /32 suffix (e.g., 203.123.45.67/32)."
  }
}

# =============================================================================
# EKS DEPENDENCY VARIABLES (from EKS module outputs)
# =============================================================================

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

# =============================================================================
# F5 BNK/SPK STORAGE CONFIGURATION
# =============================================================================

variable "enable_f5_efs_storage" {
  description = "Enable EFS storage class for F5 BNK/SPK distributed pods requiring ReadWriteMany access"
  type        = bool
  default     = true
}

variable "efs_file_system_id" {
  description = "EFS file system ID for F5 distributed storage (empty for EFS CSI auto-provisioning)"
  type        = string
  default     = ""
}

# =============================================================================
# BACKUP AND SNAPSHOT CONFIGURATION
# =============================================================================

variable "enable_volume_snapshots" {
  description = "Enable volume snapshot classes for backup operations"
  type        = bool
  default     = true
}

variable "snapshot_retention_policy" {
  description = "Retention policy for volume snapshots"
  type        = string
  default     = "Delete"
  
  validation {
    condition     = contains(["Delete", "Retain"], var.snapshot_retention_policy)
    error_message = "Snapshot retention policy must be either Delete or Retain."
  }
}
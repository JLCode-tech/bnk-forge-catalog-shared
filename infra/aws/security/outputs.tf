# infrastructure-modules/foundation/security/outputs.tf
# Output values from security module for use by other modules

# =============================================================================
# SSH KEY OUTPUTS
# =============================================================================

output "infrastructure_key_name" {
  description = "Name of the infrastructure key pair for all EC2 instances"
  value       = aws_key_pair.infrastructure_key.key_name
}

output "infrastructure_private_key_path" {
  description = "Local path to the infrastructure private key for laptop access"
  value       = local_sensitive_file.private_key_local.filename
  sensitive   = true
}

# =============================================================================
# SECURITY GROUP OUTPUTS
# =============================================================================

output "vpc_security_group_id" {
  description = "ID of the VPC security group"
  value       = aws_security_group.vpc_sg.id
}

output "vpc_security_group_arn" {
  description = "ARN of the VPC security group"
  value       = aws_security_group.vpc_sg.arn
}

# =============================================================================
# JUMPHOST OUTPUTS
# =============================================================================

output "jumphost_instance_id" {
  description = "Instance ID of the primary jumphost"
  value       = aws_instance.jumphost.id
}

output "jumphost_public_ip" {
  description = "Public IP address of the jumphost"
  value       = aws_eip.jumphost.public_ip
}

output "jumphost_private_ip" {
  description = "Private IP address of the jumphost"
  value       = aws_instance.jumphost.private_ip
}

output "jumphost_backup_public_ip" {
  description = "Public IP address of the backup jumphost (if enabled)"
  value       = var.enable_jumphost_backup ? aws_eip.jumphost_backup[0].public_ip : null
}

output "jumphost_ssh_command" {
  description = "SSH command to connect to jumphost"
  value       = "ssh -i ${local_sensitive_file.private_key_local.filename} ec2-user@${aws_eip.jumphost.public_ip}"
  sensitive   = true
}

# =============================================================================
# IAM ROLE OUTPUTS
# =============================================================================

# EKS Cluster Role
output "eks_cluster_role_arn" {
  description = "ARN of the EKS cluster IAM role"
  value       = aws_iam_role.eks_cluster.arn
}

output "eks_cluster_role_name" {
  description = "Name of the EKS cluster IAM role"
  value       = aws_iam_role.eks_cluster.name
}

# Node Group Role
output "nodegroup_role_arn" {
  description = "ARN of the EKS node group IAM role"
  value       = aws_iam_role.nodegroup.arn
}

output "nodegroup_role_name" {
  description = "Name of the EKS node group IAM role"
  value       = aws_iam_role.nodegroup.name
}

# Jumphost Role
output "jumphost_role_arn" {
  description = "ARN of the jumphost IAM role"
  value       = aws_iam_role.jumphost_role.arn
}

output "jumphost_instance_profile_name" {
  description = "Name of the jumphost IAM instance profile"
  value       = aws_iam_instance_profile.jumphost_profile.name
}

# ENI Attachment Manager Role ARN
output "eni_attachment_manager_role_arn" {
  description = "ARN of the ENI attachment manager IAM role"
  value       = var.create_oidc_provider ? aws_iam_role.eni_attachment_manager[0].arn : null
}

# =============================================================================
# OIDC PROVIDER OUTPUTS (conditional)
# =============================================================================

output "oidc_provider_arn" {
  description = "ARN of the OIDC provider for the EKS cluster"
  value       = var.create_oidc_provider ? aws_iam_openid_connect_provider.eks[0].arn : null
}

output "oidc_provider_url" {
  description = "URL of the OIDC provider for the EKS cluster"
  value       = var.create_oidc_provider ? aws_iam_openid_connect_provider.eks[0].url : null
}

# =============================================================================
# CSI DRIVER ROLE OUTPUTS (conditional)
# =============================================================================

output "ebs_csi_driver_role_arn" {
  description = "ARN of the EBS CSI driver IAM role"
  value       = var.create_oidc_provider ? aws_iam_role.ebs_csi_driver[0].arn : null
}

output "efs_csi_driver_role_arn" {
  description = "ARN of the EFS CSI driver IAM role"
  value       = var.create_oidc_provider ? aws_iam_role.efs_csi_driver[0].arn : null
}

# =============================================================================
# F5 BNK ROLE OUTPUTS (conditional)
# =============================================================================

output "f5_bnk_service_account_role_arn" {
  description = "ARN of the F5 BNK service account IAM role"
  value       = var.create_oidc_provider && var.enable_f5_bnk_roles ? aws_iam_role.f5_bnk_service_account[0].arn : null
}

# =============================================================================
# SECURITY SUMMARY OUTPUT
# =============================================================================

output "security_summary" {
  description = "Summary of security resources created"
  value = {
    project_name            = var.project_name
    environment             = var.environment
    vpc_security_group_id   = aws_security_group.vpc_sg.id
    jumphost_public_ip      = aws_eip.jumphost.public_ip
    jumphost_instance_id    = aws_instance.jumphost.id
    infrastructure_key_name = aws_key_pair.infrastructure_key.key_name
    user_ip_restriction     = var.user_ip
    backup_jumphost_enabled = var.enable_jumphost_backup
    oidc_provider_created   = var.create_oidc_provider
    f5_roles_enabled        = var.enable_f5_bnk_roles
  }
}
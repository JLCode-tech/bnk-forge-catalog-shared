# infrastructure-modules/foundation/eks/outputs.tf

# EKS Cluster Outputs
output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "Endpoint of the EKS cluster"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_version" {
  description = "Version of the EKS cluster"
  value       = aws_eks_cluster.main.version
}

output "cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = aws_eks_cluster.main.arn
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

# Node Group Outputs
output "nodegroup_name" {
  description = "Name of the EKS node group"
  value       = aws_eks_node_group.main.node_group_name
}

output "nodegroup_arn" {
  description = "ARN of the EKS node group"
  value       = aws_eks_node_group.main.arn
}

output "nodegroup_status" {
  description = "Status of the EKS node group"
  value       = aws_eks_node_group.main.status
}

# OIDC Provider Outputs
output "oidc_provider_arn" {
  description = "ARN of the OIDC provider for the EKS cluster"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "oidc_provider_url" {
  description = "URL of the OIDC provider for the EKS cluster"
  value       = aws_iam_openid_connect_provider.eks.url
}

# CSI Driver Outputs (conditional)
output "ebs_csi_driver_role_arn" {
  description = "ARN of the EBS CSI driver IAM role"
  value       = aws_iam_role.ebs_csi_driver.arn
}

output "efs_csi_driver_role_arn" {
  description = "ARN of the EFS CSI driver IAM role"
  value       = var.enable_efs_csi_driver ? aws_iam_role.efs_csi_driver[0].arn : null
}

# Addon Status Outputs (conditional) - Use .addon_version instead of .status
output "ebs_csi_addon_version" {
  description = "Version of the EBS CSI driver addon"
  value       = aws_eks_addon.ebs_csi_driver.addon_version
}

output "efs_csi_addon_version" {
  description = "Version of the EFS CSI driver addon"
  value       = var.enable_efs_csi_driver ? aws_eks_addon.efs_csi_driver[0].addon_version : null
}

output "snapshot_controller_addon_version" {
  description = "Version of the snapshot controller addon"
  value       = var.enable_snapshot_controller ? aws_eks_addon.snapshot_controller[0].addon_version : null
}

# kubectl Configuration Command
output "kubectl_config_command" {
  description = "Command to configure kubectl for this cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name} --profile ${var.aws_profile}"
}

# Storage Validation Commands
output "storage_validation_commands" {
  description = "Commands to validate storage setup"
  value       = <<-EOT
    # Configure kubectl first
    aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name} --profile ${var.aws_profile}
    
    # Validate EBS CSI driver is running
    kubectl get pods -n kube-system -l app=ebs-csi-controller
    kubectl get pods -n kube-system -l app=ebs-csi-node
    
    # Validate EFS CSI driver is running
    kubectl get pods -n kube-system -l app=efs-csi-controller
    kubectl get pods -n kube-system -l app=efs-csi-node
    
    # Check storage classes (will be created in storage module)
    kubectl get storageclass
    
    # Test PVC creation with real storage class
    kubectl apply -f - <<EOF
    apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      name: test-pvc
    spec:
      accessModes:
        - ReadWriteOnce
      storageClassName: gp3-standard
      resources:
        requests:
          storage: 10Gi
    EOF
    
    # Check PVC status
    kubectl get pvc test-pvc
    
    # Cleanup test PVC
    kubectl delete pvc test-pvc
  EOT
}

# EKS Summary
output "eks_summary" {
  description = "Summary of EKS cluster information"
  value = {
    cluster_name      = aws_eks_cluster.main.name
    cluster_endpoint  = aws_eks_cluster.main.endpoint
    cluster_version   = aws_eks_cluster.main.version
    nodegroup_name    = aws_eks_node_group.main.node_group_name
    node_count        = var.node_count
    instance_type     = var.instance_type
    oidc_provider_arn = aws_iam_openid_connect_provider.eks.arn
    kubectl_command   = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name} --profile ${var.aws_profile}"
  }
}
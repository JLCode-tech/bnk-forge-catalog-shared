# infrastructure-modules/foundation/storage/outputs.tf
# Outputs for the storage module

# =============================================================================
# STORAGE CLASS OUTPUTS
# =============================================================================

output "default_storage_class" {
  description = "Default storage class for the cluster"
  value = {
    name        = kubernetes_storage_class.gp3_standard.metadata[0].name
    provisioner = kubernetes_storage_class.gp3_standard.storage_provisioner
    is_default  = true
  }
}

output "standard_storage_classes" {
  description = "Map of standard storage classes created"
  value = {
    gp3 = {
      name        = kubernetes_storage_class.gp3.metadata[0].name
      provisioner = kubernetes_storage_class.gp3.storage_provisioner
      type        = "gp3"
      iops        = "3000"
      throughput  = "125"
    }
    gp3_standard = {
      name        = kubernetes_storage_class.gp3_standard.metadata[0].name
      provisioner = kubernetes_storage_class.gp3_standard.storage_provisioner
      type        = "gp3"
      iops        = "3000"
      throughput  = "125"
      is_default  = true
    }
    gp3_high_iops = {
      name        = kubernetes_storage_class.gp3_high_iops.metadata[0].name
      provisioner = kubernetes_storage_class.gp3_high_iops.storage_provisioner
      type        = "gp3"
      iops        = "16000"
      throughput  = "1000"
    }
    io2_high_performance = {
      name        = kubernetes_storage_class.io2_high_performance.metadata[0].name
      provisioner = kubernetes_storage_class.io2_high_performance.storage_provisioner
      type        = "io2"
      iops        = "64000"
    }
  }
}

output "f5_storage_classes" {
  description = "F5-specific storage classes for BNK/SPK workloads"
  value = {
    f5_efs_rwx = var.enable_f5_efs_storage ? {
      name         = kubernetes_storage_class.f5_efs_rwx[0].metadata[0].name
      provisioner  = kubernetes_storage_class.f5_efs_rwx[0].storage_provisioner
      access_modes = ["ReadWriteMany"]
      use_case     = "F5 TMM and Observer pods requiring distributed storage"
    } : null
    f5_persistence = {
      name        = kubernetes_storage_class.f5_persistence.metadata[0].name
      provisioner = kubernetes_storage_class.f5_persistence.storage_provisioner
      use_case    = "F5 CWC persistence and Fluentd logging storage"
      retention   = "Retain"
    }
  }
}

# =============================================================================
# STORAGE CONFIGURATION SUMMARY
# =============================================================================

output "storage_summary" {
  description = "Summary of storage configuration"
  value = {
    cluster_name               = var.cluster_name
    region                    = var.aws_region
    project_name              = var.project_name
    environment               = var.environment
    default_storage_class     = "gp3-standard"
    f5_efs_enabled           = var.enable_f5_efs_storage
    volume_snapshots_enabled = var.enable_volume_snapshots
    encryption_enabled       = true
    storage_classes_count    = 4 + (var.enable_f5_efs_storage ? 1 : 0)
  }
}

# =============================================================================
# VALIDATION COMMANDS
# =============================================================================

output "storage_validation_commands" {
  description = "Commands to validate storage setup"
  value = <<-EOT
    # Configure kubectl first
    aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name} --profile ${var.aws_profile}
    
    # Check all storage classes
    kubectl get storageclass
    
    # Check default storage class
    kubectl get storageclass -o json | jq '.items[] | select(.metadata.annotations["storageclass.kubernetes.io/is-default-class"] == "true") | .metadata.name'
    
    # Verify CSI drivers are running (from EKS module)
    kubectl get pods -n kube-system -l app=ebs-csi-controller
    kubectl get pods -n kube-system -l app=ebs-csi-node
    kubectl get pods -n kube-system -l app=efs-csi-controller
    kubectl get pods -n kube-system -l app=efs-csi-node
    
    # Test PVC creation with default storage class
    kubectl apply -f - <<EOF
    apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      name: test-storage-pvc
    spec:
      accessModes:
        - ReadWriteOnce
      storageClassName: gp3-standard
      resources:
        requests:
          storage: 10Gi
    EOF
    
    # Check PVC status
    kubectl get pvc test-storage-pvc
    kubectl describe pvc test-storage-pvc
    
    # Test F5 EFS storage (if enabled)
    %{if var.enable_f5_efs_storage}kubectl get storageclass f5-efs-rwx%{endif}
    
    # Check volume snapshot classes (if enabled)
    %{if var.enable_volume_snapshots}kubectl get volumesnapshotclass%{endif}
    
    # Cleanup test PVC
    kubectl delete pvc test-storage-pvc
  EOT
}
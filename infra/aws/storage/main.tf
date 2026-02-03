# infrastructure-modules/foundation/storage/main.tf
# Storage module - Storage classes and F5 BNK/SPK specific storage requirements

# =============================================================================
# DATA SOURCES
# =============================================================================

# EKS cluster information
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

# EKS cluster auth - uses AWS credentials from environment variables
data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}

# =============================================================================
# PROVIDER CONFIGURATION
# =============================================================================

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

# =============================================================================
# LOCAL VALUES
# =============================================================================

locals {
  common_tags = merge(var.common_tags, {
    Module = "storage"
  })
}

# =============================================================================
# WAIT FOR CSI DRIVERS TO BE READY
# =============================================================================

# Wait for EBS CSI driver to be ready before creating storage classes
resource "time_sleep" "wait_for_csi_drivers" {
  create_duration = "60s"

  # This ensures CSI drivers from EKS module are ready
  triggers = {
    cluster_name = var.cluster_name
  }
}

# =============================================================================
# STANDARD STORAGE CLASSES
# =============================================================================

# GP3 Storage Class for general purpose workloads
resource "kubernetes_storage_class" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/description" = "GP3 storage class for general purpose workloads"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
  reclaim_policy         = "Delete"

  parameters = {
    type       = "gp3"
    iops       = "3000"
    throughput = "125"
    encrypted  = "true"
  }

  depends_on = [time_sleep.wait_for_csi_drivers]
}

# GP3 Standard (Default) Storage Class
resource "kubernetes_storage_class" "gp3_standard" {
  metadata {
    name = "gp3-standard"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
      "storageclass.kubernetes.io/description"      = "Default GP3 storage class with standard performance"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
  reclaim_policy         = "Delete"

  parameters = {
    type       = "gp3"
    iops       = "3000"
    throughput = "125"
    encrypted  = "true"
  }

  depends_on = [time_sleep.wait_for_csi_drivers]
}

# High IOPS Storage Class for performance workloads
resource "kubernetes_storage_class" "gp3_high_iops" {
  metadata {
    name = "gp3-high-iops"
    annotations = {
      "storageclass.kubernetes.io/description" = "High IOPS GP3 storage class for performance workloads"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
  reclaim_policy         = "Delete"

  parameters = {
    type       = "gp3"
    iops       = "16000" # Max IOPS for gp3
    throughput = "1000"  # Max throughput for gp3
    encrypted  = "true"
  }

  depends_on = [time_sleep.wait_for_csi_drivers]
}

# IO2 Storage Class for ultra-high performance (DPDK/F5 workloads)
resource "kubernetes_storage_class" "io2_high_performance" {
  metadata {
    name = "io2-high-performance"
    annotations = {
      "storageclass.kubernetes.io/description" = "Ultra-high performance IO2 storage class for DPDK and F5 workloads"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
  reclaim_policy         = "Delete"

  parameters = {
    type      = "io2"
    iops      = "64000" # High IOPS for performance workloads
    encrypted = "true"
  }

  depends_on = [time_sleep.wait_for_csi_drivers]
}

# =============================================================================
# F5 BNK/SPK SPECIFIC STORAGE REQUIREMENTS
# =============================================================================

# EFS Storage Class for F5 distributed pods (ReadWriteMany access)
# F5 BNK/SPK requires ReadWriteMany access for TMM and Observer pods running on separate nodes
resource "kubernetes_storage_class" "f5_efs_rwx" {
  count = var.enable_f5_efs_storage ? 1 : 0

  metadata {
    name = "f5-efs-rwx"
    annotations = {
      "storageclass.kubernetes.io/description" = "EFS storage class for F5 BNK/SPK TMM and Observer pods requiring ReadWriteMany access"
    }
  }

  storage_provisioner    = "efs.csi.aws.com"
  volume_binding_mode    = "Immediate"
  allow_volume_expansion = true
  reclaim_policy         = "Delete"

  parameters = {
    provisioningMode = "efs-ap"
    fileSystemId     = var.efs_file_system_id != "" ? var.efs_file_system_id : ""
    directoryPerms   = "0755"
    gidRangeStart    = "1000"
    gidRangeEnd      = "2000"
    basePath         = "/f5-shared"
  }

  depends_on = [time_sleep.wait_for_csi_drivers]
}

# F5 Persistence Storage Class for CWC (Cluster Wide Controller) and Fluentd logging
resource "kubernetes_storage_class" "f5_persistence" {
  metadata {
    name = "f5-persistence"
    annotations = {
      "storageclass.kubernetes.io/description" = "Storage class for F5 CWC persistence and Fluentd logging storage"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
  reclaim_policy         = "Retain" # Retain for F5 persistence data

  parameters = {
    type       = "gp3"
    iops       = "3000"
    throughput = "125"
    encrypted  = "true"
    fsType     = "ext4"
  }

  depends_on = [time_sleep.wait_for_csi_drivers]
}

# =============================================================================
# VOLUME SNAPSHOT CLASSES FOR BACKUP/RECOVERY
# =============================================================================

# EBS Volume Snapshot Class for backup operations
resource "kubernetes_manifest" "ebs_volume_snapshot_class" {
  count = var.enable_volume_snapshots ? 1 : 0

  manifest = {
    apiVersion = "snapshot.storage.k8s.io/v1"
    kind       = "VolumeSnapshotClass"
    metadata = {
      name = "ebs-snapshot-class"
      annotations = {
        "snapshot.storage.kubernetes.io/is-default-class" = "true"
      }
    }
    driver         = "ebs.csi.aws.com"
    deletionPolicy = var.snapshot_retention_policy
    parameters = {
      encrypted = "true"
    }
  }

  depends_on = [time_sleep.wait_for_csi_drivers]
}
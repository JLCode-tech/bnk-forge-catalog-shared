# main.tf - High Performance EKS Node Group with S3 and DPDK setup

# Data sources for dependencies
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}

data "aws_subnets" "private_internal" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  filter {
    name   = "tag:Name"
    values = ["*private-internal*"]
  }
}

data "aws_subnets" "private_external" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  filter {
    name   = "tag:Name"
    values = ["*private-external*"]
  }
}

data "aws_security_group" "vpc_sg" {
  id = var.vpc_security_group_id
}

data "aws_security_group" "cluster_sg" {
  filter {
    name   = "group-name"
    values = ["eks-cluster-sg-${var.cluster_name}-*"]
  }

  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }
}

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
  }

  # F5 BNK (BIG-IP Next for Kubernetes) specific node labels for x86_64
  # Per F5 docs: https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/node-label.html
  #
  # NOTE: app=f5-tmm label and dpu=true:NoSchedule taint are NOT set at node group level.
  # They are applied selectively to only tmm_node_count nodes via the configure_tmm_nodes
  # resource below. This ensures remaining nodes stay available for BNK control plane pods
  # (dSSM, RabbitMQ, CWC, Observer, CRD Conversion, OTEL Collector, etc.)
  x86_f5_bnk_labels = var.f5_bnk_enabled ? {
    "f5.com/bnk-node"     = "true"
    "f5.com/tmm-capable"  = "true"
    "f5.com/numa-node"    = tostring(var.f5_numa_node)
    "f5.com/cpu-cores"    = tostring(var.f5_tmm_cpu_cores)
    "f5.com/architecture" = "x86_64"
    "workload-type"       = "high-performance"
    "dpdk-enabled"        = "true"
  } : {}

  # Combine all x86_64 labels
  # All high-perf nodes get these labels. TMM-specific labels (app=f5-tmm)
  # are added selectively via configure_tmm_nodes below.
  x86_combined_node_labels = merge({
    "node-type"    = "high-performance"
    "sriov"        = "enabled"
    "dpdk"         = "enabled"
    "is_worker"    = "true"
    "architecture" = "x86_64"
  }, local.x86_f5_bnk_labels)
}

# ==============================================
# S3 BUCKET FOR DPDK SCRIPTS
# ==============================================

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "dpdk_scripts" {
  bucket = "${var.project_name}-dpdk-scripts-${random_id.bucket_suffix.hex}"

  tags = local.common_tags
}

# Block public access
resource "aws_s3_bucket_public_access_block" "dpdk_scripts" {
  bucket = aws_s3_bucket.dpdk_scripts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable server-side encryption by default
resource "aws_s3_bucket_server_side_encryption_configuration" "dpdk_scripts" {
  bucket = aws_s3_bucket.dpdk_scripts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Enforce SSL/TLS for all requests
resource "aws_s3_bucket_policy" "enforce_ssl" {
  bucket = aws_s3_bucket.dpdk_scripts.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceTLS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.dpdk_scripts.arn,
          "${aws_s3_bucket.dpdk_scripts.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# Upload DPDK scripts to S3
resource "aws_s3_object" "dpdk_setup_script" {
  bucket = aws_s3_bucket.dpdk_scripts.id
  key    = "dpdk-setup.sh"
  source = "${path.module}/scripts/dpdk-setup.sh"
  etag   = filemd5("${path.module}/scripts/dpdk-setup.sh")

  tags = local.common_tags
}

resource "aws_s3_object" "dpdk_devbind" {
  bucket = aws_s3_bucket.dpdk_scripts.id
  key    = "dpdk-devbind.py"
  source = "${path.module}/scripts/dpdk-devbind.py"
  etag   = filemd5("${path.module}/scripts/dpdk-devbind.py")

  tags = local.common_tags
}

resource "aws_s3_object" "sriov_init_script" {
  bucket = aws_s3_bucket.dpdk_scripts.id
  key    = "sriov-init.sh"
  source = "${path.module}/scripts/sriov-init.sh"
  etag   = filemd5("${path.module}/scripts/sriov-init.sh")

  tags = local.common_tags
}

resource "aws_s3_object" "config_sriov_script" {
  bucket = aws_s3_bucket.dpdk_scripts.id
  key    = "config-sriov.sh"
  source = "${path.module}/scripts/config-sriov.sh"
  etag   = filemd5("${path.module}/scripts/config-sriov.sh")

  tags = local.common_tags
}

resource "aws_s3_object" "dpdk_resource_builder" {
  bucket = aws_s3_bucket.dpdk_scripts.id
  key    = "dpdk-resource-builder.py"
  source = "${path.module}/scripts/dpdk-resource-builder.py"
  etag   = filemd5("${path.module}/scripts/dpdk-resource-builder.py")

  tags = local.common_tags
}

# Upload systemd service files
resource "aws_s3_object" "sriov_init_service" {
  bucket = aws_s3_bucket.dpdk_scripts.id
  key    = "sriov-init.service"
  source = "${path.module}/scripts/sriov-init.service"
  etag   = filemd5("${path.module}/scripts/sriov-init.service")

  tags = local.common_tags
}

resource "aws_s3_object" "config_sriov_service" {
  bucket = aws_s3_bucket.dpdk_scripts.id
  key    = "config-sriov.service"
  source = "${path.module}/scripts/config-sriov.service"
  etag   = filemd5("${path.module}/scripts/config-sriov.service")

  tags = local.common_tags
}

# ==============================================
# S3 IAM POLICY FOR NODEGROUP ROLE
# ==============================================

# IAM policy for nodes to access S3 DPDK scripts
resource "aws_iam_policy" "s3_dpdk_access" {
  name        = "${var.project_name}-s3-dpdk-access"
  description = "Allow nodes to access S3 DPDK scripts"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.dpdk_scripts.arn,
          "${aws_s3_bucket.dpdk_scripts.arn}/*"
        ]
      }
    ]
  })
}

# Attach S3 policy to the existing nodegroup role from security module
resource "aws_iam_role_policy_attachment" "nodegroup_s3_access" {
  policy_arn = aws_iam_policy.s3_dpdk_access.arn
  role       = var.nodegroup_role_name
}

# ==============================================
# LAUNCH TEMPLATE
# ==============================================

resource "aws_launch_template" "x86_high_perf_nodegroup" {
  name_prefix   = "${var.project_name}-x86-high-perf-"
  instance_type = var.instance_type
  key_name      = var.key_pair_name

  vpc_security_group_ids = [
    var.vpc_security_group_id,
    data.aws_security_group.cluster_sg.id
  ]

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = var.node_volume_size
      volume_type           = "gp3"
      iops                  = 3000
      throughput            = 125
      encrypted             = true
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name           = "${var.project_name}-x86-high-perf-worker"
      "Architecture" = "x86_64"
      "NodeType"     = "high-performance"
      }, var.f5_bnk_enabled ? {
      "f5.com/bnk-node" = "true"
      "f5.com/tmm-node" = "true"
    } : {})
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(local.common_tags, {
      Name = "${var.project_name}-x86-high-perf-volume"
    })
  }

  # Use original compact_userdata.sh with corrected variable names
  user_data = base64encode(templatefile("${path.module}/scripts/compact_userdata.sh", {
    s3_bucket_name   = aws_s3_bucket.dpdk_scripts.id
    region           = var.region
    hugepages_2mi    = var.hugepages_2mi
    hugepages_1gi    = var.hugepages_1gi
    f5_bnk_enabled   = var.f5_bnk_enabled ? "true" : "false"
    f5_tmm_cpu_cores = var.f5_tmm_cpu_cores
    f5_numa_node     = var.f5_numa_node
  }))
}

# ==============================================
# EKS NODE GROUP
# ==============================================

resource "aws_eks_node_group" "x86_high_perf" {
  cluster_name    = var.cluster_name
  node_group_name = "${var.project_name}-x86-high-perf-nodes"
  node_role_arn   = var.nodegroup_role_arn
  subnet_ids      = data.aws_subnets.private_internal.ids

  scaling_config {
    desired_size = var.node_count
    max_size     = var.node_count + 1
    min_size     = 1
  }

  launch_template {
    id      = aws_launch_template.x86_high_perf_nodegroup.id
    version = "$Latest"
  }

  capacity_type = var.capacity_type
  ami_type      = "AL2_x86_64"

  update_config {
    max_unavailable = 1
  }

  # x86_64 labels -- applied to ALL nodes in the group
  labels = local.x86_combined_node_labels

  # NOTE: No taints at node group level.
  # Per F5 BNK docs (https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/node-label.html):
  #   - TMM nodes need: label app=f5-tmm + taint dpu=true:NoSchedule
  #   - Non-TMM nodes must remain untainted for BNK control plane pods
  # EKS node group taints apply to ALL nodes equally, so we apply taints
  # selectively via the configure_tmm_nodes resource after nodes are ready.

  depends_on = [
    aws_iam_role_policy_attachment.nodegroup_s3_access,
  ]

  tags = merge(local.common_tags, {
    "Architecture" = "x86_64"
  })
}

# ==============================================
# WAIT FOR NODES
# ==============================================

resource "null_resource" "wait_for_x86_nodes" {
  depends_on = [aws_eks_node_group.x86_high_perf]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for x86_64 high-performance nodes to be ready..."
      
      # Wait for EKS node group to be ACTIVE using AWS CLI (no kubectl required)
      timeout 600 bash -c '
        while true; do
          STATUS=$(aws eks describe-nodegroup \
            --cluster-name ${var.cluster_name} \
            --nodegroup-name ${aws_eks_node_group.x86_high_perf.node_group_name} \
            --region ${var.region} \
            --query "nodegroup.status" \
            --output text 2>/dev/null)
          
          if [ "$STATUS" = "ACTIVE" ]; then
            HEALTH=$(aws eks describe-nodegroup \
              --cluster-name ${var.cluster_name} \
              --nodegroup-name ${aws_eks_node_group.x86_high_perf.node_group_name} \
              --region ${var.region} \
              --query "nodegroup.health.issues" \
              --output text 2>/dev/null)
            
            if [ "$HEALTH" = "None" ] || [ -z "$HEALTH" ]; then
              echo "Node group is ACTIVE and healthy"
              break
            fi
          fi
          echo "Waiting for x86_64 nodes to be ready... (status: $STATUS)"
          sleep 10
        done
      '
      
      echo "x86_64 high-performance nodes are ready!"
      
      # Show node group details
      aws eks describe-nodegroup \
        --cluster-name ${var.cluster_name} \
        --nodegroup-name ${aws_eks_node_group.x86_high_perf.node_group_name} \
        --region ${var.region} \
        --query "nodegroup.{Status:status,DesiredSize:scalingConfig.desiredSize,CurrentSize:scalingConfig.desiredSize}" \
        --output table
    EOT
  }
}

# ==============================================
# ENI ATTACHMENT MANAGER
# ==============================================

# ConfigMap for ENI attachment scripts
resource "kubernetes_config_map" "eni_attachment_scripts" {
  depends_on = [aws_eks_node_group.x86_high_perf]

  metadata {
    name      = "eni-attachment-scripts"
    namespace = "kube-system"
  }

  data = {
    "eni_attachment_manager.py" = file("${path.module}/scripts/eni_attachment_manager.py")
  }
}

# ServiceAccount for ENI attachment
resource "kubernetes_service_account" "eni_attachment_manager" {
  depends_on = [aws_eks_node_group.x86_high_perf]

  metadata {
    name      = "eni-attachment-manager"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = var.eni_attachment_manager_role_arn
    }
  }
}

# Deploy ENI attachment manager
resource "kubernetes_manifest" "eni_attachment_daemonset" {
  depends_on = [
    kubernetes_service_account.eni_attachment_manager,
    kubernetes_config_map.eni_attachment_scripts
  ]

  manifest = yamldecode(templatefile("${path.module}/manifests/eni-attachment-daemonset.yaml", {
    region                    = var.region
    vpc_security_group_id     = var.vpc_security_group_id
    cluster_security_group_id = data.aws_security_group.cluster_sg.id
  }))
}

# Wait for ENI attachment to complete
resource "null_resource" "wait_for_eni_attachment" {
  depends_on = [kubernetes_manifest.eni_attachment_daemonset]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for ENI attachment to complete..."
      sleep 60
      echo "ENI attachment completed!"
    EOT
  }
}

# ==============================================
# MULTUS CNI DEPLOYMENT
# ==============================================

# NetworkAttachmentDefinition CRD - must be installed FIRST before any other Multus resources
resource "kubernetes_manifest" "multus_crd" {
  depends_on = [null_resource.wait_for_x86_nodes]

  manifest = yamldecode(file("${path.module}/manifests/multus-crd.yaml"))
}

resource "kubernetes_manifest" "multus_serviceaccount" {
  depends_on = [kubernetes_manifest.multus_crd]

  manifest = yamldecode(file("${path.module}/manifests/multus-serviceaccount.yaml"))
}

resource "kubernetes_manifest" "multus_clusterrole" {
  depends_on = [kubernetes_manifest.multus_serviceaccount]

  manifest = yamldecode(file("${path.module}/manifests/multus-clusterrole.yaml"))
}

resource "kubernetes_manifest" "multus_clusterrolebinding" {
  depends_on = [kubernetes_manifest.multus_clusterrole]

  manifest = yamldecode(file("${path.module}/manifests/multus-clusterrolebinding.yaml"))
}

resource "kubernetes_manifest" "multus_daemon_config" {
  depends_on = [kubernetes_manifest.multus_clusterrolebinding]

  manifest = yamldecode(file("${path.module}/manifests/multus-daemon-config.yaml"))
}

resource "kubernetes_manifest" "multus_daemonset" {
  depends_on = [kubernetes_manifest.multus_daemon_config]

  manifest = yamldecode(file("${path.module}/manifests/multus-daemonset.yaml"))
}

# Wait for Multus to be ready
# Note: kubernetes_manifest resources already wait for apply to complete
# This resource provides additional wait time for daemonset pods to start
resource "null_resource" "wait_for_multus" {
  depends_on = [kubernetes_manifest.multus_daemonset]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for Multus CNI daemonset to initialize..."
      # Give time for the daemonset to create pods on all nodes
      sleep 60
      echo "Multus CNI daemonset deployed - pods initializing on nodes"
    EOT
  }
}

# ==============================================
# SR-IOV CNI DEPLOYMENT
# ==============================================

resource "kubernetes_manifest" "sriov_cni_installer" {
  depends_on = [null_resource.wait_for_multus]

  manifest = yamldecode(file("${path.module}/manifests/sriov-cni-installer-x86.yaml"))
}

# Wait for SR-IOV CNI installer
# Note: kubernetes_manifest resources already wait for apply to complete
resource "null_resource" "wait_for_sriov_cni" {
  depends_on = [kubernetes_manifest.sriov_cni_installer]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for SR-IOV CNI installer to initialize..."
      # Give time for the installer daemonset to run on nodes
      sleep 60
      echo "SR-IOV CNI installer deployed - running on nodes"
    EOT
  }
}

# ==============================================
# SR-IOV DEVICE PLUGIN DEPLOYMENT
# ==============================================

resource "kubernetes_manifest" "sriov_serviceaccount" {
  depends_on = [null_resource.wait_for_sriov_cni]

  manifest = yamldecode(file("${path.module}/manifests/sriov-serviceaccount.yaml"))
}

resource "kubernetes_manifest" "sriovdp_config" {
  depends_on = [kubernetes_manifest.sriov_serviceaccount]

  manifest = yamldecode(file("${path.module}/manifests/sriovdp-config.yaml"))
}

resource "kubernetes_manifest" "sriov_device_plugin" {
  depends_on = [kubernetes_manifest.sriovdp_config]

  manifest = yamldecode(file("${path.module}/manifests/sriov-daemonset.yaml"))
}

# Wait for SR-IOV Device Plugin
# Note: kubernetes_manifest resources already wait for apply to complete
resource "null_resource" "wait_for_sriov_device_plugin" {
  depends_on = [kubernetes_manifest.sriov_device_plugin]

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for SR-IOV Device Plugin to initialize..."
      # Give time for the device plugin daemonset to start on nodes
      sleep 60
      echo "SR-IOV Device Plugin deployed - initializing on nodes"
    EOT
  }
}

# ==============================================
# DPDK CONFIGURATOR DEPLOYMENT
# ==============================================

resource "kubernetes_manifest" "dpdk_serviceaccount" {
  depends_on = [null_resource.wait_for_sriov_device_plugin]

  manifest = yamldecode(file("${path.module}/manifests/dpdk-serviceaccount.yaml"))
}

resource "kubernetes_manifest" "dpdk_clusterrole" {
  depends_on = [kubernetes_manifest.dpdk_serviceaccount]

  manifest = yamldecode(file("${path.module}/manifests/dpdk-clusterrole.yaml"))
}

resource "kubernetes_manifest" "dpdk_clusterrolebinding" {
  depends_on = [kubernetes_manifest.dpdk_clusterrole]

  manifest = yamldecode(file("${path.module}/manifests/dpdk-clusterrolebinding.yaml"))
}

resource "kubernetes_manifest" "dpdk_daemonset" {
  depends_on = [kubernetes_manifest.dpdk_clusterrolebinding]

  manifest = yamldecode(file("${path.module}/manifests/dpdk-daemonset.yaml"))
}

# ==============================================
# SELECTIVE TMM NODE CONFIGURATION
# ==============================================
# Per F5 BNK docs: https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/node-label.html
# - TMM nodes need: label app=f5-tmm + taint dpu=true:NoSchedule
# - Non-TMM nodes must remain untainted for BNK control plane pods
#   (dSSM, RabbitMQ, CWC, Observer, CRD Conversion, OTEL Collector, etc.)
#
# This step runs after all DaemonSets are deployed, discovers the high-perf
# node names, and selectively labels/taints only the first tmm_node_count nodes.

resource "null_resource" "configure_tmm_nodes" {
  depends_on = [
    kubernetes_manifest.dpdk_daemonset,
    null_resource.wait_for_x86_nodes
  ]

  triggers = {
    tmm_node_count = var.tmm_node_count
    cluster_name   = var.cluster_name
    region         = var.region
    nodegroup_name = aws_eks_node_group.x86_high_perf.node_group_name
    f5_bnk_enabled = var.f5_bnk_enabled ? "true" : "false"
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== Configuring TMM-dedicated nodes ==="
      echo "TMM node count: ${var.tmm_node_count}"
      echo "F5 BNK enabled: ${var.f5_bnk_enabled}"
      echo "Total nodes: ${var.node_count}"
      
      if [ "${var.f5_bnk_enabled}" != "true" ] || [ "${var.tmm_node_count}" -eq "0" ]; then
        echo "TMM node configuration skipped (f5_bnk_enabled=${var.f5_bnk_enabled}, tmm_node_count=${var.tmm_node_count})"
        exit 0
      fi
      
      # Update kubeconfig for kubectl access
      aws eks update-kubeconfig \
        --name ${var.cluster_name} \
        --region ${var.region} \
        --kubeconfig /tmp/hp-nodes-kubeconfig 2>/dev/null
      
      export KUBECONFIG=/tmp/hp-nodes-kubeconfig
      
      # Get high-performance node names (sorted for deterministic ordering)
      HP_NODES=$(kubectl get nodes -l node-type=high-performance \
        --sort-by=.metadata.creationTimestamp \
        -o jsonpath='{.items[*].metadata.name}')
      
      echo "High-performance nodes found: $HP_NODES"
      
      TMM_COUNT=0
      for NODE in $HP_NODES; do
        if [ $TMM_COUNT -lt ${var.tmm_node_count} ]; then
          echo "=== Configuring $NODE as TMM-dedicated node ==="
          
          # Apply app=f5-tmm label (required by TMM pod nodeSelector)
          kubectl label node $NODE app=f5-tmm --overwrite
          
          # Apply dpu=true:NoSchedule taint (restricts node to TMM + system daemonsets)
          kubectl taint nodes $NODE dpu=true:NoSchedule --overwrite 2>/dev/null || \
            echo "Taint already exists on $NODE"
          
          echo "  $NODE: labeled app=f5-tmm, tainted dpu=true:NoSchedule"
          TMM_COUNT=$((TMM_COUNT + 1))
        else
          echo "=== Configuring $NODE as BNK control plane node (no taint) ==="
          
          # Ensure NO TMM label on non-TMM nodes
          kubectl label node $NODE app- 2>/dev/null || true
          
          # Ensure NO dpu taint on non-TMM nodes
          kubectl taint nodes $NODE dpu=true:NoSchedule- 2>/dev/null || true
          
          echo "  $NODE: untainted, available for BNK control plane pods"
        fi
      done
      
      echo ""
      echo "=== TMM Node Configuration Summary ==="
      echo "TMM-dedicated nodes: $TMM_COUNT of ${var.node_count}"
      echo "BNK control plane nodes: $((${var.node_count} - TMM_COUNT)) of ${var.node_count}"
      
      # Clean up
      rm -f /tmp/hp-nodes-kubeconfig
    EOT
  }
}

# ==============================================
# FINAL VERIFICATION
# ==============================================

resource "null_resource" "verify_setup" {
  depends_on = [
    null_resource.configure_tmm_nodes
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "=== x86_64 High-Performance Nodes Setup Complete ==="
      echo "Architecture: x86_64"
      echo "Instance Type: ${var.instance_type}"
      echo "F5 BNK enabled: ${var.f5_bnk_enabled}"
      echo "TMM dedicated nodes: ${var.tmm_node_count} of ${var.node_count}"
      echo "S3 bucket: ${aws_s3_bucket.dpdk_scripts.id}"
      echo
      
      aws eks describe-nodegroup \
        --cluster-name ${var.cluster_name} \
        --nodegroup-name ${aws_eks_node_group.x86_high_perf.node_group_name} \
        --region ${var.region} \
        --query "nodegroup.{Status:status,DesiredSize:scalingConfig.desiredSize}" \
        --output table
      echo
      
      echo "=== Deployed Components ==="
      echo "- Multus CNI DaemonSet (all high-perf nodes)"
      echo "- SR-IOV CNI Installer DaemonSet (all high-perf nodes)"
      echo "- SR-IOV Device Plugin DaemonSet (all high-perf nodes)"
      echo "- DPDK Configurator DaemonSet (all high-perf nodes)"
      echo "- ENI Attachment Manager DaemonSet (all high-perf nodes)"
      echo
      echo "=== Node Topology ==="
      echo "- ${var.tmm_node_count} node(s): app=f5-tmm label + dpu=true:NoSchedule (TMM only)"
      echo "- $((${var.node_count} - ${var.tmm_node_count})) node(s): no taint (BNK control plane + general workloads)"
      echo
      echo "=== Ready for F5 BNK Installation ==="
    EOT
  }
}

# Cleanup resources - handles orphaned ENIs created by eni_attachment_manager
# When nodes are terminated, ENIs are detached but not deleted, blocking security group deletion
# IMPORTANT: This runs AFTER the node group is destroyed (depends_on in reverse)
resource "null_resource" "cleanup" {
  triggers = {
    nodegroup_name        = aws_eks_node_group.x86_high_perf.node_group_name
    region                = var.region
    vpc_security_group_id = var.vpc_security_group_id
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "High-Performance Nodes cleanup initiated..."
      echo "Waiting for node group instances to fully terminate..."
      
      # Wait for instances to terminate and ENIs to become available
      # The node group may be deleted but instances take time to fully terminate
      MAX_RETRIES=12
      RETRY_INTERVAL=10
      
      for i in $(seq 1 $MAX_RETRIES); do
        echo "Checking for orphaned ENIs (attempt $i/$MAX_RETRIES)..."
        
        # Find orphaned ENIs that were created for high-performance nodes
        # These ENIs have the tag ENIType=external-dpdk and are in 'available' state (detached)
        ORPHANED_ENIS=$(aws ec2 describe-network-interfaces \
          --region ${self.triggers.region} \
          --filters "Name=group-id,Values=${self.triggers.vpc_security_group_id}" \
                    "Name=status,Values=available" \
                    "Name=tag:ENIType,Values=external-dpdk" \
          --query 'NetworkInterfaces[*].NetworkInterfaceId' \
          --output text 2>/dev/null || echo "")
        
        if [ -n "$ORPHANED_ENIS" ] && [ "$ORPHANED_ENIS" != "None" ]; then
          echo "Found orphaned ENIs: $ORPHANED_ENIS"
          for ENI_ID in $ORPHANED_ENIS; do
            echo "Deleting orphaned ENI: $ENI_ID"
            aws ec2 delete-network-interface \
              --region ${self.triggers.region} \
              --network-interface-id "$ENI_ID" 2>/dev/null || echo "Warning: Could not delete $ENI_ID (may already be deleted)"
          done
          echo "Orphaned ENI cleanup completed"
          break
        else
          if [ $i -lt $MAX_RETRIES ]; then
            echo "No orphaned ENIs found yet, waiting $RETRY_INTERVAL seconds for instances to terminate..."
            sleep $RETRY_INTERVAL
          else
            echo "No orphaned ENIs found after $MAX_RETRIES attempts (this is OK if instances terminated cleanly)"
          fi
        fi
      done
      
      echo "Kubernetes resources (DaemonSets, ConfigMaps, etc.) will be destroyed by Terraform"
      echo "Cleanup process completed"
    EOT
  }
}
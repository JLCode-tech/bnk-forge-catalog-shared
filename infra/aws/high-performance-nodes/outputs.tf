# outputs.tf - High Performance Nodes Module Outputs

output "nodegroup_arn" {
  description = "ARN of the high-performance node group"
  value       = aws_eks_node_group.x86_high_perf.arn
}

output "nodegroup_name" {
  description = "Name of the high-performance node group"
  value       = aws_eks_node_group.x86_high_perf.node_group_name
}

output "nodegroup_status" {
  description = "Status of the high-performance node group"
  value       = aws_eks_node_group.x86_high_perf.status
}

output "launch_template_id" {
  description = "ID of the high-performance nodes launch template"
  value       = aws_launch_template.x86_high_perf_nodegroup.id
}

output "launch_template_version" {
  description = "Latest version of the high-performance nodes launch template"
  value       = aws_launch_template.x86_high_perf_nodegroup.latest_version
}

output "node_labels" {
  description = "Labels applied to high-performance nodes"
  value       = local.x86_combined_node_labels
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket containing DPDK scripts"
  value       = aws_s3_bucket.dpdk_scripts.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket containing DPDK scripts"
  value       = aws_s3_bucket.dpdk_scripts.arn
}

output "networking_components" {
  description = "Status of networking components deployed"
  value = {
    multus_deployed    = "kube-multus-ds"
    sriov_cni_deployed = "sriov-cni-installer-x86"
    sriov_dp_deployed  = "kube-sriov-device-plugin-amd64"
    dpdk_deployed      = "dpdk-configurator"
  }
}

output "f5_bnk_readiness" {
  description = "Infrastructure readiness for F5 BNK (BIG-IP Next for Kubernetes) installation"
  value = {
    multus_cni_ready      = "NetworkAttachmentDefinition CRDs available"
    sriov_resources_ready = "SR-IOV devices available for TMM pods"
    dpdk_optimized        = "DPDK-optimized nodes with hugepages"
    networking_ready      = "Infrastructure ready for F5 BNK deployment"
    tmm_nodes             = "${var.tmm_node_count} node(s) labeled app=f5-tmm with dpu=true:NoSchedule taint"
    bnk_cp_nodes          = "${var.node_count - var.tmm_node_count} node(s) untainted for BNK control plane"
  }
}

output "dpdk_scripts_uploaded" {
  description = "List of DPDK scripts uploaded to S3"
  value = [
    "dpdk-setup.sh",
    "dpdk-devbind.py",
    "sriov-init.sh",
    "config-sriov.sh",
    "dpdk-resource-builder.py",
    "sriov-init.service",
    "config-sriov.service"
  ]
}

output "summary" {
  description = "Summary of high-performance nodes configuration"
  value = {
    project_name     = var.project_name
    environment      = var.environment
    nodegroup_name   = aws_eks_node_group.x86_high_perf.node_group_name
    nodegroup_status = aws_eks_node_group.x86_high_perf.status
    instance_type    = var.instance_type
    node_count       = var.node_count
    tmm_node_count   = var.tmm_node_count
    architecture     = "x86_64"
    f5_bnk_enabled   = var.f5_bnk_enabled
    hugepages_2mi    = var.hugepages_2mi
    hugepages_1gi    = var.hugepages_1gi
    s3_bucket        = aws_s3_bucket.dpdk_scripts.id
    networking_stack = "multus-sriov-dpdk"
  }
}

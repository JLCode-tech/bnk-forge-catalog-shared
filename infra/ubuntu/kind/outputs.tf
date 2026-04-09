output "kubeconfig_path" {
  description = "Local runner path to the kubeconfig copied back from the remote host"
  value       = local.local_kubeconfig_path
}

output "cluster_name" {
  value = var.cluster_name
}

output "cluster_endpoint" {
  description = "Cluster API endpoint as recorded in the copied kubeconfig"
  value       = try(yamldecode(file(local.local_kubeconfig_path)).clusters[0].cluster.server, null)
}

output "remote_kubeconfig_path" {
  description = "Remote host path of the generated kubeconfig file"
  value       = local.remote_kubeconfig_path
}

output "remote_host" {
  description = "Remote Ubuntu host where the kind cluster was created"
  value       = var.ssh_host
}

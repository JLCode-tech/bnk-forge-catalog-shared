output "collector_installed" {
  description = "True if the Fluent Bit DaemonSet was deployed by this module (enable_pod_log_collection = true)."
  value       = var.enable_pod_log_collection
}

# collector_ready signals that the apply phase completed successfully.
#
# When enable_pod_log_collection=true, the rollout status check inside
# null_resource.collector_install[0] causes apply to fail if Fluent Bit does
# not roll out — so reaching this output already guarantees the DaemonSet is up.
#
# Terraform/OpenTofu does not allow a counted resource (count > 0) in an
# output's depends_on list. Using local_sensitive_file.kubeconfig (non-counted)
# is sufficient because all counted resources depend on it transitively.
output "collector_ready" {
  description = "Gate output — true once the Fluent Bit DaemonSet has rolled out (or collection was disabled). Downstream live-observability-readiness depends on this."
  value       = true

  depends_on = [
    local_sensitive_file.kubeconfig,
  ]
}

output "gatewayclass_name" {
  description = "Name of the GatewayClass CR that was applied. Operator-facing Gateway CRs must reference this name via .spec.gatewayClassName."
  value       = local.gatewayclass_name_resolved
}

output "f5spkvlan_ext_applied" {
  description = "True once the ext-vlan F5SPKVlan CR has been applied to the cluster."
  value       = true

  depends_on = [
    null_resource.spkvlan_apply,
  ]
}

output "spkvlan_gatewayclass_ready" {
  description = "Gate output — true once both F5SPKVlan and GatewayClass CRs have been applied. Downstream Gateway CRs and traffic-validation steps depend on this."
  value       = true

  depends_on = [
    null_resource.spkvlan_apply,
    null_resource.gatewayclass_apply,
  ]
}

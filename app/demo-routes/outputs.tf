# bnk-forge-modules/app/demo-routes/outputs.tf

output "route_names" {
  description = "List of created HTTPRoute names"
  value = compact([
    "demo-standard-route",
    var.enable_smart_route ? "demo-smart-route" : "",
  ])
}

output "routes_created" {
  description = "Number of routes created"
  value       = 1 + (var.enable_smart_route ? 1 : 0)
}

output "routes_ready" {
  description = "Flag indicating all routes are deployed"
  value       = true
  depends_on  = [null_resource.verify_routes]
}

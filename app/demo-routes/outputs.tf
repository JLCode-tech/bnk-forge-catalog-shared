# bnk-forge-modules/app/demo-routes/outputs.tf

output "route_names" {
  description = "List of created HTTPRoute names"
  value = compact([
    "web-route",
    "api-route",
    "health-route",
    var.enable_ai_route ? "ai-route" : "",
  ])
}

output "routes_created" {
  description = "Number of routes created"
  value       = 3 + (var.enable_ai_route ? 1 : 0)
}

output "routes_ready" {
  description = "Flag indicating all routes are deployed"
  value       = true
  depends_on  = [null_resource.verify_routes]
}

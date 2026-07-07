output "observability_ready" {
  description = "True when Loki returned a 200 /ready response via the Kubernetes API-server service proxy. Traffic-producing blueprints should depend on this output before beginning log emission."
  value       = true

  depends_on = [
    null_resource.loki_readiness,
  ]
}

output "loki_proxy_url" {
  description = "Kubernetes API-server proxy path used for the Loki readiness check. Useful for diagnostics and manual verification."
  value       = local.proxy_path
}

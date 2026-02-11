# bnk-forge-modules/app/demo-traffic/outputs.tf

output "traffic_generators_deployed" {
  description = "Number of traffic generator CronJobs deployed"
  value = (
    (var.enable_web_traffic ? 1 : 0) +
    (var.enable_api_traffic ? 1 : 0) +
    (var.enable_canary_traffic ? 1 : 0) +
    (var.enable_blocked_traffic ? 1 : 0)
  )
}

output "cronjob_names" {
  description = "Names of deployed traffic generator CronJobs"
  value = compact([
    var.enable_web_traffic ? "traffic-web" : "",
    var.enable_api_traffic ? "traffic-api" : "",
    var.enable_canary_traffic ? "traffic-canary" : "",
    var.enable_blocked_traffic ? "traffic-denied" : "",
  ])
}

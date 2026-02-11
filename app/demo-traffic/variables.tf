# bnk-forge-modules/app/demo-traffic/variables.tf

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = ""
}

variable "gateway_name" {
  description = "Name of the BNK Gateway to send traffic to"
  type        = string
  default     = "demo-gw"
}

variable "gateway_namespace" {
  description = "Namespace of the BNK Gateway"
  type        = string
  default     = "demo-gw"
}

variable "app_namespace" {
  description = "Namespace for traffic generator CronJobs"
  type        = string
  default     = "demo-apps"
}

variable "enable_web_traffic" {
  description = "Enable web traffic generator (GET /)"
  type        = bool
  default     = true
}

variable "enable_api_traffic" {
  description = "Enable API traffic generator (GET/POST /api/*)"
  type        = bool
  default     = true
}

variable "enable_canary_traffic" {
  description = "Enable canary traffic generator (GET with X-Canary header)"
  type        = bool
  default     = true
}

variable "enable_blocked_traffic" {
  description = "Enable blocked source traffic generator (GET with blocked X-Forwarded-For)"
  type        = bool
  default     = true
}

variable "traffic_interval_seconds" {
  description = "Seconds between requests within each CronJob run"
  type        = number
  default     = 30

  validation {
    condition     = var.traffic_interval_seconds >= 5 && var.traffic_interval_seconds <= 300
    error_message = "Traffic interval must be between 5 and 300 seconds."
  }
}

# Dependency inputs
variable "gateway_ready" {
  description = "Flag from demo-gateway module"
  type        = bool
  default     = true
}

variable "routes_ready" {
  description = "Flag from demo-routes module indicating routes are deployed"
  type        = bool
}

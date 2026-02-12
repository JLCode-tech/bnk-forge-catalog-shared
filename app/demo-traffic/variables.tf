# bnk-forge-modules/app/demo-traffic/variables.tf

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = ""
}

variable "app_namespace" {
  description = "Namespace for traffic generator CronJobs and backend services"
  type        = string
  default     = "demo-apps"
}

variable "backend_service_name" {
  description = "Name of the backend K8s Service to target (demo-web is always deployed)"
  type        = string
  default     = "demo-web"
}

variable "backend_service_port" {
  description = "Port of the backend K8s Service"
  type        = number
  default     = 80
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

# bnk-forge-modules/app/demo-routes/variables.tf

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = ""
}

variable "gateway_name" {
  description = "Name of the BNK Gateway to attach routes to"
  type        = string
  default     = "demo-gw"
}

variable "gateway_namespace" {
  description = "Namespace of the BNK Gateway"
  type        = string
  default     = "demo-gw"
}

variable "app_namespace" {
  description = "Namespace where demo applications are deployed"
  type        = string
  default     = "demo-apps"
}

variable "enable_canary_routing" {
  description = "Enable header-based canary routing to backend service"
  type        = bool
  default     = true
}

variable "canary_weight" {
  description = "Percentage of traffic to route to canary backend (0-100)"
  type        = number
  default     = 20

  validation {
    condition     = var.canary_weight >= 0 && var.canary_weight <= 100
    error_message = "Canary weight must be between 0 and 100."
  }
}

variable "enable_ai_route" {
  description = "Enable AI chat route on the smart listener (port 8080)"
  type        = bool
  default     = true
}

# Dependency input
variable "gateway_ready" {
  description = "Flag from demo-gateway module indicating Gateway is ready"
  type        = bool
}

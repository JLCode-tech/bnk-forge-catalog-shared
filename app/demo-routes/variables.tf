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
  description = "Namespace of the BNK Gateway (routes are created here)"
  type        = string
  default     = "bnk-gw"
}

variable "app_namespace" {
  description = "Namespace where backend applications are deployed"
  type        = string
  default     = "demo-apps"
}

variable "backend_service_name" {
  description = "Name of the backend Kubernetes Service to route traffic to"
  type        = string
  default     = "litellm-proxy"
}

variable "backend_service_port" {
  description = "Port of the backend Kubernetes Service"
  type        = number
  default     = 4000
}

variable "enable_smart_route" {
  description = "Enable smart-http route on port 8080 (requires smart listener on Gateway)"
  type        = bool
  default     = true
}

# Dependency input
variable "gateway_ready" {
  description = "Flag from demo-gateway module indicating Gateway is ready"
  type        = bool
}

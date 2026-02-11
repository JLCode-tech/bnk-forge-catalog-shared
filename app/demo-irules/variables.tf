# bnk-forge-modules/app/demo-irules/variables.tf

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = ""
}

variable "gateway_name" {
  description = "Name of the BNK Gateway to attach network policies to"
  type        = string
  default     = "demo-gw"
}

variable "gateway_namespace" {
  description = "Namespace of the BNK Gateway"
  type        = string
  default     = "demo-gw"
}

variable "observability_namespace" {
  description = "Namespace where Fluent Bit is deployed"
  type        = string
  default     = "observability"
}

variable "fluentbit_hsl_port" {
  description = "UDP port for Fluent Bit HSL receiver"
  type        = number
  default     = 5514
}

variable "enable_https_listener" {
  description = "Whether HTTPS listener exists on the Gateway"
  type        = bool
  default     = true
}

variable "enable_smart_listener" {
  description = "Whether Smart listener exists on the Gateway"
  type        = bool
  default     = true
}

# Dependency inputs
variable "gateway_ready" {
  description = "Flag from demo-gateway module indicating Gateway is ready"
  type        = bool
}

variable "observability_ready" {
  description = "Flag from demo-observability module indicating observability stack is ready"
  type        = bool
  default     = true
}

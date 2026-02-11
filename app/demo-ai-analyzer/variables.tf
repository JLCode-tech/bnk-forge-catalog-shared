# bnk-forge-modules/app/demo-ai-analyzer/variables.tf

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = ""
}

variable "gateway_name" {
  description = "Name of the BNK Gateway"
  type        = string
  default     = "demo-gw"
}

variable "gateway_namespace" {
  description = "Namespace of the BNK Gateway (F5BigAnalyzer and iRules deploy here)"
  type        = string
  default     = "demo-gw"
}

variable "app_namespace" {
  description = "Namespace where AI proxy is deployed"
  type        = string
  default     = "demo-apps"
}

variable "observability_namespace" {
  description = "Namespace where Fluent Bit is deployed (for HSL token logging)"
  type        = string
  default     = "observability"
}

variable "fluentbit_hsl_port" {
  description = "UDP port for Fluent Bit HSL receiver"
  type        = number
  default     = 5514
}

variable "prometheus_endpoint" {
  description = "Full Prometheus endpoint URL for the Analyzer data source"
  type        = string
  default     = "http://prometheus-service.demo-apps.svc.cluster.local:9090"
}

variable "bedrock_smart_model_id" {
  description = "Bedrock model ID for the smart/complex tier (passed to analyzer script)"
  type        = string
  default     = "anthropic.claude-sonnet-4-20250514-v1:0"
}

variable "bedrock_fast_model_id" {
  description = "Bedrock model ID for the fast/cheap tier (passed to analyzer script)"
  type        = string
  default     = "amazon.nova-micro-v1:0"
}

variable "analyzer_schedule" {
  description = "How often the Analyzer runs (Xm, Xh, or Xd)"
  type        = string
  default     = "1m"

  validation {
    condition     = can(regex("^\\d+[mhd]$", var.analyzer_schedule))
    error_message = "Schedule must be in format Xm, Xh, or Xd (e.g., 1m, 2h, 1d)."
  }
}

variable "enable_token_irule" {
  description = "Deploy AI token counting iRule with HSL logging"
  type        = bool
  default     = true
}

# Dependency inputs
variable "ai_proxy_ready" {
  description = "Flag from demo-ai-proxy module indicating proxy stack is deployed"
  type        = bool
}

variable "gateway_ready" {
  description = "Flag from demo-gateway module indicating Gateway is ready"
  type        = bool
  default     = true
}

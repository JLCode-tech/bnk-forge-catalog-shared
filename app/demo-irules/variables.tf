# bnk-forge-modules/app/demo-irules/variables.tf
# Variables for Token Counting HSL + SmartLLM Routing iRules

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
  description = "Namespace of the BNK Gateway (iRules + BNKNetPolicies must be in same ns)"
  type        = string
  default     = "bnk-gw"
}

# --- HSL Observability ---

variable "fluentbit_hsl_endpoint" {
  description = "Fluent Bit HSL UDP endpoint (host:port) for token telemetry"
  type        = string
  default     = "fluentbit-hsl-udp.observability.svc.cluster.local:5514"
}

# --- SmartLLM Routing ---

variable "enable_smart_listener" {
  description = "Whether Smart listener exists on the Gateway (enables SmartLLM iRule + combined policy)"
  type        = bool
  default     = true
}

variable "classifier_host" {
  description = "Hostname of the prompt classifier service for sideband calls"
  type        = string
  default     = "prompt-classifier.demo-apps.svc.cluster.local"
}

variable "classifier_port" {
  description = "Port of the prompt classifier service"
  type        = number
  default     = 80
}

variable "complex_model_name" {
  description = "LiteLLM model name for complex/reasoning prompts (routed via Bedrock)"
  type        = string
  default     = "bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0"
}

variable "simple_model_name" {
  description = "LiteLLM model name for simple/fast prompts (routed via Bedrock)"
  type        = string
  default     = "bedrock/amazon.nova-micro-v1:0"
}

variable "complexity_threshold" {
  description = "Weighted complexity score threshold (0.0-1.0). Above = complex model, below = simple."
  type        = number
  default     = 0.5

  validation {
    condition     = var.complexity_threshold >= 0 && var.complexity_threshold <= 1
    error_message = "Complexity threshold must be between 0.0 and 1.0."
  }
}

variable "token_quota_limit" {
  description = "Per-user token quota limit. Users exceeding this are forced to simple model."
  type        = number
  default     = 1000

  validation {
    condition     = var.token_quota_limit >= 100
    error_message = "Token quota limit must be at least 100."
  }
}

# --- Dependency inputs ---

variable "gateway_ready" {
  description = "Flag from demo-gateway module indicating Gateway is ready"
  type        = bool
}

variable "observability_ready" {
  description = "Flag from demo-observability module indicating observability stack is ready"
  type        = bool
  default     = true
}

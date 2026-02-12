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

# NOTE: SmartLLM classifier/routing variables removed — the current iRules are
# simplified stubs that insert headers. When full SmartLLM routing is implemented,
# re-add: classifier_host, classifier_port, complex_model_name, simple_model_name,
# complexity_threshold, token_quota_limit.

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

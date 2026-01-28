# infrastructure-modules/bnk/f5biganalyzer/variables.tf
# F5BigAnalyzer Module Variables - AI Load Balancing Analyzer (EA)

# =============================================================================
# REQUIRED VARIABLES
# =============================================================================

variable "cluster_name" {
  description = "Name of the Kubernetes cluster (used for resource naming and identification)"
  type        = string
}

variable "analyzer_name" {
  description = "Name of the F5BigAnalyzer resource"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.analyzer_name))
    error_message = "Analyzer name must be valid Kubernetes resource name"
  }
}

variable "analyzer_namespace" {
  description = "Namespace where analyzer will be deployed"
  type        = string
}

variable "llm_workload_config" {
  description = "LLM workload configuration"
  type = object({
    model_type         = string           # gpt, claude, llama, etc.
    max_tokens         = number           # Maximum token limit
    context_window     = optional(number) # Context window size
    streaming_enabled  = optional(bool, true)
    batch_size         = optional(number, 1)
  })

  validation {
    condition     = contains(["gpt", "claude", "llama", "mistral", "palm", "other"], var.llm_workload_config.model_type)
    error_message = "Model type must be gpt, claude, llama, mistral, palm, or other"
  }
}

# =============================================================================
# OPTIONAL VARIABLES
# =============================================================================

variable "routing_algorithm" {
  description = "AI routing algorithm for load balancing"
  type        = string
  default     = "token-aware"

  validation {
    condition     = contains(["token-aware", "latency-optimized", "cost-optimized", "round-robin"], var.routing_algorithm)
    error_message = "Routing algorithm must be token-aware, latency-optimized, cost-optimized, or round-robin"
  }
}

variable "enable_metrics" {
  description = "Enable metrics collection and export"
  type        = bool
  default     = true
}

variable "metrics_port" {
  description = "Port for metrics endpoint"
  type        = number
  default     = 9090
}

# =============================================================================
# DEPENDENCY INPUTS
# =============================================================================

variable "flo_ready" {
  description = "Dependency flag indicating FLO is ready and CRDs are installed"
  type        = bool
}

# =============================================================================
# TAGS AND LABELS
# =============================================================================

variable "common_labels" {
  description = "Common labels to apply to all Kubernetes resources"
  type        = map(string)
  default     = {}
}

variable "annotations" {
  description = "Annotations to add to the analyzer resource"
  type        = map(string)
  default     = {}
}

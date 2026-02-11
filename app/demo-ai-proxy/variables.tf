# bnk-forge-modules/app/demo-ai-proxy/variables.tf

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = ""
}

variable "app_namespace" {
  description = "Namespace for demo application workloads (LiteLLM + Prometheus deploy here)"
  type        = string
  default     = "demo-apps"
}

variable "gateway_name" {
  description = "Name of the BNK Gateway for AI route"
  type        = string
  default     = "demo-gw"
}

variable "gateway_namespace" {
  description = "Namespace of the BNK Gateway"
  type        = string
  default     = "demo-gw"
}

variable "aws_region" {
  description = "AWS region for Bedrock API calls"
  type        = string
  default     = "ap-southeast-2"
}

variable "bedrock_smart_model_id" {
  description = "Bedrock model ID for the 'smart' (complex/expensive) model tier"
  type        = string
  default     = "anthropic.claude-sonnet-4-20250514-v1:0"
}

variable "bedrock_fast_model_id" {
  description = "Bedrock model ID for the 'fast' (simple/cheap) model tier"
  type        = string
  default     = "amazon.nova-micro-v1:0"
}

variable "bedrock_iam_role_arn" {
  description = "IAM Role ARN for IRSA — gives LiteLLM pods bedrock:InvokeModel permission. Leave empty to use node instance profile."
  type        = string
  default     = ""
}

variable "litellm_replicas" {
  description = "Number of LiteLLM proxy replicas (the Analyzer adjusts weights across these)"
  type        = number
  default     = 2

  validation {
    condition     = var.litellm_replicas >= 1 && var.litellm_replicas <= 10
    error_message = "LiteLLM replicas must be between 1 and 10."
  }
}

variable "litellm_image" {
  description = "LiteLLM container image"
  type        = string
  default     = "ghcr.io/berriai/litellm:main-v1.63.2"
}

variable "enable_ai_route" {
  description = "Create an HTTPRoute on the smart listener for AI chat traffic"
  type        = bool
  default     = true
}

# Dependency inputs
variable "namespaces_ready" {
  description = "Flag from demo-namespace module indicating namespaces are ready"
  type        = bool
}

variable "gateway_ready" {
  description = "Flag from demo-gateway module indicating Gateway is ready"
  type        = bool
  default     = true
}

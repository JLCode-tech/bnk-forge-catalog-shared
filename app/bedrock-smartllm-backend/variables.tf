variable "namespace" {
  type        = string
  default     = "default"
  description = "Namespace where backends, Gateway, HTTPRoute, and analyzer CR are deployed."
}

variable "bedrock_role_arn" {
  type        = string
  description = "IAM role ARN usable via IRSA. Must trust the EKS OIDC provider and allow bedrock:InvokeModel on the three foundation-model ARNs. See README for a creation snippet."
}

variable "aws_region" {
  type        = string
  default     = "ap-southeast-2"
  description = "AWS region for Bedrock calls. Pre-check model availability — Nova + Haiku regional coverage varies."
}

variable "models" {
  type = map(object({
    model_id = string
    weight   = number
  }))
  default = {
    "nova-micro" = {
      model_id = "amazon.nova-micro-v1:0"
      weight   = 33
    }
    "nova-lite" = {
      model_id = "amazon.nova-lite-v1:0"
      weight   = 33
    }
    "claude-3-haiku" = {
      model_id = "anthropic.claude-3-haiku-20240307-v1:0"
      weight   = 34
    }
  }
  description = "Map of logical backend name → Bedrock model ID + starting HTTPRoute weight. Weights should sum to 100."
}

variable "shim_image" {
  type        = string
  default     = "python:3.12-slim"
  description = "Base image used by both the pip-install init container and the runtime container. The shim source itself ships via ConfigMap — no custom image build required."
}

variable "gateway_class" {
  type        = string
  default     = "bnk-gatewayclass"
  description = "GatewayClass name for the BNK CNE controller."
}

variable "gateway_name" {
  type    = string
  default = "llm-gateway"
}

variable "gateway_vip" {
  type        = string
  description = "IPv4 VIP the BNK Gateway should bind. Must be in the external VLAN's prefix and unused. See README for how to find one."
}

variable "httproute_name" {
  type    = string
  default = "llm-route"
}

variable "analyzer_name" {
  type    = string
  default = "smartllm-analyzer"
}

variable "analyzer_schedule" {
  type        = string
  default     = "1m"
  description = "How often the F5BigAnalyzer reconciles. Format: Xm / Xh / Xd (e.g. 1m, 2h, 1d)."
}

variable "prometheus_endpoint" {
  type        = string
  default     = "http://kube-prometheus-stack-prometheus.monitoring:9090"
  description = "HTTP URL the analyzer uses to query metrics. Override if not using kube-prometheus-stack or if it's installed under a different release."
}

variable "prometheus_release_label" {
  type        = string
  default     = "kube-prometheus-stack"
  description = "Value of the `release` label Prometheus operator's serviceMonitorSelector matches. ServiceMonitors this module creates will carry this label."
}

variable "common_labels" {
  type    = map(string)
  default = {}
}

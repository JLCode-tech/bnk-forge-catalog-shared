variable "namespace" {
  type        = string
  default     = "bnk-demo-client"
  description = "Namespace for the client. Intentionally different from the backend's namespace to demonstrate cross-namespace traffic through the BNK Gateway."
}

variable "create_namespace" {
  type        = bool
  default     = true
  description = "Whether this module should create the namespace. Set to false if the namespace is managed elsewhere."
}

variable "gateway_url" {
  type        = string
  description = "URL the client POSTs chat completions to. Typically http://<gateway_vip>. Usually wired from the backend module's gateway_vip output."
}

variable "replicas" {
  type        = number
  default     = 1
  description = "How many client pods to run. Each runs its own independent Poisson loop."
}

variable "request_rate" {
  type        = number
  default     = 1.0
  description = "Target requests per second per pod, Poisson-distributed (bursty — not a metronome)."
}

variable "max_tokens" {
  type        = number
  default     = 128
  description = "max_tokens sent in each chat completion request."
}

variable "request_timeout_seconds" {
  type    = number
  default = 30
}

variable "client_image" {
  type        = string
  default     = "python:3.12-slim"
  description = "Base image. Client source ships via ConfigMap + pip-install init container — no custom build needed."
}

variable "prometheus_release_label" {
  type        = string
  default     = "kube-prometheus-stack"
  description = "Value of the `release` label that Prometheus operator's serviceMonitorSelector matches."
}

variable "common_labels" {
  type    = map(string)
  default = {}
}

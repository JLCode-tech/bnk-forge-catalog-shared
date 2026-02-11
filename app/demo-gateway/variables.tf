# bnk-forge-modules/app/demo-gateway/variables.tf

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = ""
}

variable "gateway_name" {
  description = "Name of the BNK Gateway resource"
  type        = string
  default     = "demo-gw"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.gateway_name))
    error_message = "Gateway name must be a valid Kubernetes resource name."
  }
}

variable "gateway_namespace" {
  description = "Namespace for the Gateway resource"
  type        = string
  default     = "demo-gw"
}

variable "gatewayclass_name" {
  description = "Name of the GatewayClass to use (created by BNK stack)"
  type        = string
  default     = "bnk-gatewayclass"
}

variable "enable_https_listener" {
  description = "Enable HTTPS listener on port 443 with TLS termination"
  type        = bool
  default     = true
}

variable "enable_smart_listener" {
  description = "Enable Smart listener on port 8080 for AI/special routing"
  type        = bool
  default     = true
}

variable "cluster_issuer_name" {
  description = "cert-manager ClusterIssuer name for TLS certificates"
  type        = string
  default     = "bnk-ca-cluster-issuer"
}

# Dependency input
variable "namespaces_ready" {
  description = "Flag from demo-namespace module indicating namespaces are ready"
  type        = bool
}

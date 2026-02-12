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
  description = "Namespace for the Gateway resource (must match demo-namespace gateway_namespace)"
  type        = string
  default     = "bnk-gw"
}

variable "gatewayclass_name" {
  description = "Name of the GatewayClass to use (created by BNK stack)"
  type        = string
  default     = "bnk-gatewayclass"
}

variable "gateway_vip" {
  description = "Static VIP address for the Gateway on the external data-plane subnet. Must be registered as a secondary IP on the TMM ENI."
  type        = string
  default     = "10.0.10.100"

  validation {
    condition     = var.gateway_vip == "" || can(regex("^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$", var.gateway_vip))
    error_message = "The gateway_vip must be a valid IPv4 address or an empty string."
  }
}

# NOTE: F5BnkGateway/IPAM is NOT needed for static VIP deployments.
# The F5 internal AWS guide uses simple Gateway with addresses: [VIP] only.
# Keeping this variable for future use if dynamic IPAM is needed.
variable "bnkgateway_name" {
  description = "DEPRECATED: F5BnkGateway is not needed for static VIP. Leave empty."
  type        = string
  default     = ""
}

variable "enable_smart_listener" {
  description = "Enable Smart listener on port 8080 for AI/SmartLLM routing"
  type        = bool
  default     = true
}

# Dependency input
variable "namespaces_ready" {
  description = "Flag from demo-namespace module indicating namespaces are ready"
  type        = bool
}

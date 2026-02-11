# bnk-forge-modules/app/demo-security/variables.tf

variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = ""
}

variable "gateway_name" {
  description = "Name of the BNK Gateway to attach security policies to"
  type        = string
  default     = "demo-gw"
}

variable "gateway_namespace" {
  description = "Namespace of the BNK Gateway"
  type        = string
  default     = "bnk-gw"
}

variable "allowed_source_ranges" {
  description = "CIDR ranges allowed through the firewall"
  type        = list(string)
  default     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
}

variable "blocked_source_ranges" {
  description = "CIDR ranges blocked by the firewall (RFC5737 documentation range by default)"
  type        = list(string)
  default     = ["198.51.100.0/24"]
}

variable "enable_rate_limiting" {
  description = "Enable rate limiting on the security policy"
  type        = bool
  default     = true
}

variable "rate_limit_rps" {
  description = "Requests per second rate limit"
  type        = number
  default     = 100

  validation {
    condition     = var.rate_limit_rps >= 1 && var.rate_limit_rps <= 10000
    error_message = "Rate limit must be between 1 and 10000 requests per second."
  }
}

# Dependency input
variable "gateway_ready" {
  description = "Flag from demo-gateway module indicating Gateway is ready"
  type        = bool
}

variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster hosting the bedrock-smartllm-backend pods. Used to look up the OIDC issuer URL for the role trust policy."
}

variable "aws_region" {
  type        = string
  default     = "ap-southeast-2"
  description = "AWS region (informational — doesn't affect the foundation-model ARNs, which use `*` for region)."
}

variable "role_name" {
  type        = string
  default     = "bnk-bedrock-smartllm"
  description = "Name for the IAM role."
}

variable "sa_namespace" {
  type        = string
  default     = "default"
  description = "Kubernetes namespace containing the ServiceAccount. Must match the backend module's `namespace` input."
}

variable "sa_name" {
  type        = string
  default     = "bedrock-smartllm"
  description = "Kubernetes ServiceAccount name. Must match what the backend module creates (hardcoded to `bedrock-smartllm` today)."
}

variable "model_ids" {
  type = list(string)
  default = [
    "amazon.nova-micro-v1:0",
    "amazon.nova-lite-v1:0",
    "anthropic.claude-3-haiku-20240307-v1:0",
  ]
  description = "List of Bedrock foundation-model IDs the role is allowed to invoke. ARNs are generated as `arn:aws:bedrock:*::foundation-model/<id>` (double-colon: no account ID, AWS-owned models)."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to the IAM role."
}

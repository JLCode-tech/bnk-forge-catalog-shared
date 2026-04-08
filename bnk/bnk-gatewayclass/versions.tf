# bnk/bnk-gatewayclass/versions.tf
# Provider configuration is injected by BNK-Forge platform (bnk_forge_providers.tf)
# Platform-agnostic: no cloud-specific provider requirements

terraform {
  required_version = ">= 1.3.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20"
    }

    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0"
    }

    time = {
      source  = "hashicorp/time"
      version = ">= 0.9"
    }

    null = {
      source  = "hashicorp/null"
      version = ">= 3.2"
    }
  }
}

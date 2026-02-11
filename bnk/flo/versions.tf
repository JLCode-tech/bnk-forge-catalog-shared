# bnk/flo/versions.tf
# Provider configuration is injected by BNK-Forge platform (bnk_forge_providers.tf)
# aws is required so the platform injects EKS data sources for kubeconfig generation

terraform {
  required_version = ">= 1.3.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20"
    }

    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.9"
    }

    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
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

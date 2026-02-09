# k8s/bnk-namespaces/versions.tf
# Provider requirements for BNK Namespaces module

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20.0"
    }
  }
}

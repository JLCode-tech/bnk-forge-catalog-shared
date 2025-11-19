# infrastructure-modules/foundation/storage/versions.tf
# Provider requirements for storage module

terraform {
  required_version = ">= 1.0"

  # Empty backend block - required for Terragrunt remote_state
  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}
# spk-2.1/modules/foundation/vpc/versions.tf
# VPC module provider requirements (minimal)

terraform {
  required_version = ">= 1.0"
  
  # Empty backend block - required for Terragrunt remote_state
  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
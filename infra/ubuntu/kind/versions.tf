terraform {
  required_version = ">= 1.4"

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0"
    }
    terraform = {
      source  = "hashicorp/terraform"
      version = ">= 1.0"
    }
  }
}

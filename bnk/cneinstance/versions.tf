# bnk/cneinstance/versions.tf
# Provider configuration is injected by BNK-Forge platform
# This module uses kubectl for CRD management to avoid schema validation issues

terraform {
  required_version = ">= 1.3.0"

  required_providers {
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

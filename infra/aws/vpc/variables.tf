# spk-2.1/modules/foundation/vpc/variables.tf
# VPC module variables - minimal, focused on VPC-specific inputs

variable "project_name" {
  description = "Name of the project - used for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Network Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR block for public subnet (jumphost)"
  type        = string
}

variable "private_external_subnet_a_cidr" {
  description = "CIDR block for private external subnet in AZ-A"
  type        = string
}

variable "private_external_subnet_b_cidr" {
  description = "CIDR block for private external subnet in AZ-B"
  type        = string
}

variable "private_internal_subnet_a_cidr" {
  description = "CIDR block for private internal subnet in AZ-A"
  type        = string
}

variable "private_internal_subnet_b_cidr" {
  description = "CIDR block for private internal subnet in AZ-B"
  type        = string
}
# bnk-forge-modules/app/demo-ec2-traffic/variables.tf
# EC2 Traffic Generator on external subnet — hits BNK VIP externally

variable "project_name" {
  description = "Project name prefix for resource naming"
  type        = string
  default     = "bnk-demo"
}

variable "cluster_name" {
  description = "Name of the Kubernetes cluster (used by provider injection)"
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "EC2 instance type for the traffic generator"
  type        = string
  default     = "t3.micro"
}

variable "external_subnet_id" {
  description = "Subnet ID for the external data-plane subnet (10.0.10.0/24)"
  type        = string
}

variable "security_group_id" {
  description = "Security group ID allowing traffic within the VPC"
  type        = string
}

variable "key_pair_name" {
  description = "SSH key pair name for EC2 access"
  type        = string
}

variable "vip_address" {
  description = "BNK Gateway VIP address on the external subnet"
  type        = string
  default     = "10.0.10.100"
}

variable "tmm_external_ip" {
  description = "TMM external self-IP for connectivity checks"
  type        = string
  default     = "10.0.10.240"
}

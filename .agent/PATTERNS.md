# Code Patterns

> **KEEP LEAN**: Max 130 lines. Show minimal examples only.
> Don't duplicate MODULE_METADATA_SCHEMA.md or README.md content.

Last Updated: 2026-02-09

## Module Structure
```
module-name/
├── main.tf          # Resources
├── variables.tf     # Inputs with descriptions + validation
├── outputs.tf       # Outputs with descriptions
├── versions.tf      # Provider constraints
├── module.json      # BNK-Forge metadata
└── README.md        # Usage + examples
```

## Terraform

### Naming
```hcl
resource "aws_vpc" "main" {
  tags = merge(var.common_tags, {
    Name = "${var.project_name}-vpc"
  })
}
```

### Variables
```hcl
variable "capacity_type" {
  description = "Node capacity type"
  type        = string
  default     = "ON_DEMAND"
  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.capacity_type)
    error_message = "Must be ON_DEMAND or SPOT."
  }
}
```

### Outputs
```hcl
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}
```

### Dependencies
```hcl
resource "helm_release" "component" {
  depends_on = [var.prerequisite_ready]
}

output "module_ready" {
  description = "Signal module is ready"
  value       = true
  depends_on  = [helm_release.component]
}
```

### Helm
```hcl
resource "helm_release" "app" {
  values = [yamlencode({
    image = { repository = var.image_registry }
  })]
}
```

## module.json
```json
{
  "module": {
    "name": "Module Name",
    "path": "category/module",
    "version": "1.0.0",
    "description": "What it does"
  },
  "dependencies": { "required": [], "optional": [] },
  "inputs": {
    "required": [{ "name": "var", "type": "string", "source": "user" }],
    "optional": []
  },
  "outputs": { "key_outputs": [] }
}
```
Full schema: `MODULE_METADATA_SCHEMA.md`

## Security
- No hardcoded secrets
- Use `sensitive = true` for secrets
- Secure defaults (`enable_public = false`)
- Least privilege IAM

## Gotchas

### EKS Subnet Tags
```hcl
tags = {
  "kubernetes.io/cluster/${var.project_name}-cluster" = "owned"
  "kubernetes.io/role/internal-elb" = "1"
}
```

### Provider Versions
```hcl
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}
```

## Validation Commands
```bash
terraform fmt -check -recursive
terraform validate
find . -name "module.json" -exec jq empty {} \;
```

# vpc

## Description

Infrastructure module for AWS VPC with enhanced destroy reliability. Creates a VPC with 5 subnets (1 public, 4 private), Internet Gateway, NAT Gateway, and proper routing.

**Enhanced Destroy Features:**
- Automatic ENI cleanup before VPC deletion
- EIP disassociation handling
- Internet Gateway detachment automation
- Time delays for AWS API consistency
- Comprehensive cleanup verification

## Category

- **Type**: Infrastructure
- **Provider**: AWS
- **Workflow Compatibility**: Greenfield

## Requirements

- Terraform >= 1.0
- Terragrunt >= 0.45
- AWS CLI configured with appropriate credentials

## Usage

```hcl
terraform {
  source = "git::https://github.com/JLCode-tech/bnk-forge-modules.git//infra/aws/vpc?ref=v1.0.0"
}

inputs = {
  project_name     = "my-project"
  environment      = "dev"
  vpc_cidr         = "10.0.0.0/16"
  aws_region       = "us-east-1"
  aws_profile      = "default"
  # See variables below for complete list
}
```

## Destroy Reliability

This module includes enhanced cleanup provisioners that run during `terraform destroy` to handle common AWS dependency issues:

1. **ENI Cleanup**: Automatically detaches and deletes orphaned Elastic Network Interfaces
2. **EIP Handling**: Disassociates and cleans up Elastic IPs
3. **IGW Detachment**: Ensures Internet Gateway is properly detached before deletion
4. **Time Delays**: Built-in waits for AWS API consistency

These features significantly reduce manual intervention during infrastructure teardown, especially after EKS cluster deletion.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_name | Name of the project - used for resource naming | string | - | yes |
| environment | Environment name | string | - | yes |
| vpc_cidr | CIDR block for VPC | string | - | yes |
| public_subnet_cidr | CIDR block for public subnet | string | - | yes |
| private_external_subnet_a_cidr | CIDR block for private external subnet in AZ-A | string | - | yes |
| private_external_subnet_b_cidr | CIDR block for private external subnet in AZ-B | string | - | yes |
| private_internal_subnet_a_cidr | CIDR block for private internal subnet in AZ-A | string | - | yes |
| private_internal_subnet_b_cidr | CIDR block for private internal subnet in AZ-B | string | - | yes |
| aws_region | AWS region for resource cleanup during destroy | string | - | yes |
| aws_profile | AWS CLI profile for resource cleanup during destroy | string | "default" | no |
| common_tags | Common tags to apply to all resources | map(string) | {} | no |

## Outputs

See [outputs.tf](outputs.tf) for all available outputs.

## Dependencies

This module has no dependencies and should be deployed first in your infrastructure stack.

## Testing Status

⚪ Not tested - This module has not yet been validated by automated testing.

## Version

Current version: 1.0.0

## Changelog

### 2026-01-30 - Enhanced Destroy Reliability
- Added automatic ENI cleanup provisioner
- Added EIP disassociation handling
- Added Internet Gateway detachment automation
- Added time delays for AWS API consistency
- Added cleanup verification logging

## Maintainer

BNK-Forge Team

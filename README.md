# BNK-Forge Official Module Library

This repository contains the official BNK-Forge module library - a curated collection of Terragrunt modules for deploying infrastructure, Kubernetes, and BNK applications.

## Overview

This is a **read-only reference library** that is synced into the BNK-Forge tool. Users select modules from this catalog through the BNK-Forge UI, which then generates their customized project in `bnk-forge-live`.

## Repository Structure

```
bnk-forge-modules/
├── infra/                    # Infrastructure modules
│   ├── aws/
│   │   ├── vpc/
│   │   ├── eks/
│   │   └── rds/
│   ├── azure/
│   │   ├── vnet/
│   │   ├── aks/
│   │   └── sql/
│   └── gcp/
│       ├── vpc/
│       ├── gke/
│       └── cloudsql/
├── k8s/                      # Kubernetes modules
│   ├── monitoring/
│   ├── ingress/
│   ├── cert-manager/
│   └── storage/
└── bnk/                      # BNK application modules
    ├── core/
    ├── api/
    └── web/
```

## Module Categories

### Infrastructure (infra)
Cloud infrastructure components - networks, compute, databases, etc.
- **Workflow Compatibility**: Greenfield only
- **Providers**: AWS, Azure, GCP, On-Prem

### Kubernetes (k8s)
Kubernetes cluster components and add-ons
- **Workflow Compatibility**: Greenfield, Partial (assumes infra exists)
- **Providers**: Cloud-agnostic (works on any K8s cluster)

### BNK Applications (bnk)
BNK-specific application components
- **Workflow Compatibility**: Greenfield, Partial, Minimal (assumes infra+k8s exist)
- **Providers**: Cloud-agnostic

## Module Standards

Each module should include:
- `terragrunt.hcl` - Terragrunt configuration
- `README.md` - Module documentation
- `variables.tf` - Input variables (if using Terraform source)
- `outputs.tf` - Output values (if using Terraform source)

## Testing

Modules in this repository are automatically tested by BNK-Forge:
- ✅ **Green badge**: Passed `terragrunt init` and `terragrunt plan`
- ⚪ **Grey badge**: Not yet tested or test failed

## Usage

**Do not clone or modify this repository directly.**

Users interact with these modules through the BNK-Forge UI:
1. Select modules from the catalog
2. Configure variables
3. BNK-Forge generates a customized project in `bnk-forge-live`
4. Deploy from your live project

## Maintenance

- This repo is managed by the BNK-Forge team
- Modules are versioned using git tags
- Submit PRs for new modules or improvements
- All modules must pass automated testing before merge

## Related Repositories

- **bnk-forge**: Main BNK-Forge application
- **bnk-forge-live**: User deployment projects (one folder per project)

---

For more information, see the [BNK-Forge Documentation](https://github.com/JLCode-tech/bnk-forge)

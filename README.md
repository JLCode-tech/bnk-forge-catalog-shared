# BNK-Forge Official Module Library

![Latest Release](https://img.shields.io/badge/Latest-release/2.2-blue)
![F5 BNK](https://img.shields.io/badge/F5_BNK-2.2_GA-orange)
![Status](https://img.shields.io/badge/Status-Production-brightgreen)

Terraform/Terragrunt module library for deploying F5 BIG-IP Next for Kubernetes (BNK) via BNK-Forge.

## Branching Strategy

> **`main` mirrors the latest stable release branch.** All development and releases happen on `release/X.Y` branches mapped to F5 BNK GA version numbers.

| Branch | Purpose | Status |
|--------|---------|--------|
| **`release/2.2`** | F5 BNK 2.2 GA modules | **Current stable** |
| `release/2.3` | F5 BNK 2.3 (future) | Planned |
| `main` | Snapshot of latest stable release | Always mirrors latest `release/X.Y` |

### How It Works

```
main  ◄──── always reset to latest stable release branch
  │
  ├── release/2.2  ◄──── active development for BNK 2.2 GA
  │
  ├── release/2.3  ◄──── future: BNK 2.3 GA (branched from release/2.2)
  │
  └── release/2.4  ◄──── future: BNK 2.4 GA (branched from release/2.3)
```

- **New BNK version?** Branch `release/X.Y` from the previous release
- **Bug fix?** Commit to the appropriate `release/X.Y` branch
- **Main updated?** Only when a new release branch becomes the latest stable
- **No feature branches, no PRs to main** — all work targets a release branch

### For BNK-Forge Users

Point your module library at the release branch matching your F5 BNK version:

```
Module Library Git URL: https://github.com/JLCode-tech/bnk-forge-modules.git
Module Library Git Ref: release/2.2
```

## What's In This Library

A curated collection of **36+ Terraform modules** organized in three tiers:

```
bnk-forge-modules/
├── infra/aws/               # Cloud infrastructure (VPC, EKS, security, storage, HP nodes)
├── k8s/                     # Kubernetes prerequisites (namespaces, cert-manager, Multus CNI)
├── bnk/                     # BNK components (FLO, CNEInstance, VLANs, Gateway API, policies)
├── app/                     # Demo application stack (GenAI, observability, traffic gen)
└── archived/                # Deprecated modules (now managed by FLO)
```

### BNK 2.2 Deployment Flow (14 modules)

```
Infrastructure:    vpc → security → eks → storage → high-performance-nodes
K8s Prerequisites: bnk-prerequisites → cert-manager → network-setup
BNK Platform:      flo → cneinstance → bnk-vlans
Gateway API:       bnk-gatewayclass → gateway → routes
```

FLO (F5 Lifecycle Operator) auto-deploys CWC, DSSM, TMM, and all CRDs when CNEInstance is applied.

## Module Standards

Every module includes:
- `main.tf` / `variables.tf` / `outputs.tf` / `versions.tf`
- `module.json` — BNK-Forge metadata for auto-wiring
- `README.md` — Usage, inputs, outputs, examples

## Usage

**Do not clone or modify this repository directly.** Users interact through BNK-Forge UI:
1. Select modules from the catalog
2. Configure variables
3. BNK-Forge generates project in `bnk-forge-live`
4. Deploy with Terragrunt

## Documentation

- [F5 Lifecycle Operator](https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/bnk-f5-lifecycle-operator.html)
- [BIG-IP Next for Kubernetes CRDs](https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/spk-custom-resources.html)
- [Gateway API](https://gateway-api.sigs.k8s.io/)
- [DEPENDENCY_GRAPH.md](./DEPENDENCY_GRAPH.md) — Full module dependency map
- [MODULE_METADATA_SCHEMA.md](./MODULE_METADATA_SCHEMA.md) — module.json specification

## Related Repositories

- **bnk-forge** — Main BNK-Forge application
- **bnk-forge-live** — User deployment projects (generated)

---

**Current Release:** `release/2.2` (F5 BNK 2.2 GA) | **Last Tested:** 2026-02-10

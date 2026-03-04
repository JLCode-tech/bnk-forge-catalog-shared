# BNK-Forge Official Module Library

![Version](https://img.shields.io/badge/Version-2.2--rev.25-blue)
![Branch](https://img.shields.io/badge/Branch-release/2.2-green)
![F5 BNK](https://img.shields.io/badge/F5_BNK-2.2_GA-orange)
![Status](https://img.shields.io/badge/Status-Tested-brightgreen)

This repository contains the official BNK-Forge module library - a curated collection of Terraform/Terragrunt modules for deploying infrastructure, Kubernetes prerequisites, and BIG-IP Next for Kubernetes (BNK) components.

**Last Tested:** 2026-02-10 (full 14-module stack deployed on aws-sydney-bnk-demo-cluster)

> **IMPORTANT:** Always use the `release/2.2` branch for production deployments. The `main` branch is for development and may be unstable.

## Version Compatibility

| Module Branch | bnk-forge-v2 | F5 BNK Version | Status |
|---------------|--------------|----------------|--------|
| **release/2.2** | 2.6.x | 2.2 GA | **Current - Tested** |
| main | Development | N/A | Unstable |

### Configuring BNK-Forge to Use This Library

In BNK-Forge v2, go to **Settings > Defaults** and set:

```
Module Library Git URL: https://github.com/JLCode-tech/bnk-forge-modules.git
Module Library Git Ref: release/2.2
```

Then sync the catalog at **Settings > Environment Config > Sync Modules**.

## Overview

This is a **read-only reference library** that is synced into the BNK-Forge tool. Users select modules from this catalog through the BNK-Forge UI, which then generates their customized project in `bnk-forge-live`.

## Repository Structure

```
bnk-forge-modules/
├── infra/                    # Infrastructure modules
│   └── aws/
│       ├── vpc/              # AWS VPC with public/private subnets
│       ├── eks/              # Amazon EKS cluster
│       ├── security/         # Security groups, IAM, jumphost
│       ├── storage/          # EBS gp3, EFS, volume snapshots
│       └── high-performance-nodes/  # SR-IOV, DPDK, hugepages, Multus
├── k8s/                      # Kubernetes prerequisite modules
│   ├── bnk-prerequisites/    # Namespaces, FAR secrets, manifest parsing
│   ├── cert-manager/         # F5 cert-manager (TLS certificates)
│   └── network-setup/        # Multus CNI network attachment definitions
├── bnk/                      # BIG-IP Next for Kubernetes modules
│   ├── flo/                  # F5 Lifecycle Operator (core operator)
│   ├── cneinstance/          # CNEInstance CR (triggers FLO component deployment)
│   ├── bnk-vlans/            # F5SPKVlan CRs (TMM data-plane IPs + AWS ENI)
│   ├── bnk-gatewayclass/     # Standard GatewayClass (gateway.networking.k8s.io/v1)
│   ├── bnk-gateway-ext/      # F5BnkGateway CR (IPAM integration)
│   ├── gateway/              # Gateway API Gateway instances
│   ├── routes/               # HTTPRoute, GRPCRoute, L4Route
│   ├── bnk-netpolicy/        # BNKNetPolicy (TCP profiles, iRules, logging)
│   ├── bnk-secpolicy/        # BNKSecPolicy (firewall, DDoS, ACL)
│   └── far-setup/            # FAR image pull secrets (legacy — use bnk-prerequisites)
├── app/                      # Demo application modules
│   ├── demo-namespace/       # Demo namespace setup
│   ├── demo-apps/            # Backend demo applications
│   ├── demo-gateway/         # Demo Gateway instance
│   ├── demo-routes/          # Demo HTTPRoute configuration
│   ├── demo-security/        # Demo security policies
│   ├── demo-irules/          # Demo iRules
│   ├── demo-ai-proxy/        # LiteLLM Bedrock proxy
│   ├── demo-ai-analyzer/     # F5BigAnalyzer for AI Intelligent LB
│   ├── demo-observability/   # Fluent Bit + Loki logging
│   ├── demo-traffic/         # In-cluster traffic generator
│   └── demo-ec2-traffic/     # EC2-based external traffic source
├── archived/                 # Deprecated modules (managed by FLO)
└── templates/                # Module templates
```

## BNK Deployment Flow (v2.2)

### 1. Infrastructure (AWS)
| Order | Module | Purpose |
|-------|--------|---------|
| 1 | `infra/aws/vpc` | VPC, subnets, NAT gateway |
| 2 | `infra/aws/security` | Security groups, IAM, jumphost |
| 3 | `infra/aws/eks` | EKS cluster and node groups |
| 4 | `infra/aws/storage` | EBS gp3 storage class, EFS |
| 5 | `infra/aws/high-performance-nodes` | SR-IOV, DPDK, hugepages, TMM node pool |

### 2. Kubernetes Prerequisites
| Order | Module | Purpose |
|-------|--------|---------|
| 6 | `k8s/bnk-prerequisites` | Namespaces, FAR secrets, manifest download |
| 7 | `k8s/cert-manager` | TLS certificate management (ClusterIssuer) |
| 8 | `k8s/network-setup` | Multus CNI network attachment definitions |

### 3. BNK Platform
| Order | Module | Purpose |
|-------|--------|---------|
| 9 | `bnk/flo` | F5 Lifecycle Operator (Helm) |
| 10 | `bnk/cneinstance` | CNEInstance CR — triggers FLO to deploy all BNK components |
| 11 | `bnk/bnk-vlans` | F5SPKVlan CRs — TMM data-plane IP configuration |

### 4. Gateway API
| Order | Module | Purpose |
|-------|--------|---------|
| 12 | `bnk/bnk-gatewayclass` | Standard GatewayClass |
| 13 | `bnk/gateway` | Gateway instances (listeners, TLS, policies) |
| 14 | `bnk/routes` | HTTPRoute, GRPCRoute, L4Route |

### FLO Auto-Deploys
When CNEInstance + GatewayClass are applied, FLO automatically deploys:
- CWC (Cluster-Wide Controller)
- DSSM (Distributed Session State Manager)
- TMM (Traffic Management Microkernel)
- F5 Ingress, Fluentd, Observer, OTEL, RabbitMQ
- All CRDs

## Module Categories

### Infrastructure (infra)
Cloud infrastructure components - networks, compute, storage
- **Workflow Compatibility**: Greenfield only
- **Providers**: AWS (Azure, GCP planned)

### Kubernetes (k8s)
Kubernetes cluster prerequisites and add-ons
- **Workflow Compatibility**: Greenfield, Partial
- **Providers**: Cloud-agnostic

### BNK Applications (bnk)
BIG-IP Next for Kubernetes components
- **Workflow Compatibility**: Greenfield, Partial, Minimal
- **Providers**: Cloud-agnostic (requires Kubernetes)

### Demo Applications (app)
Reference demo stack with GenAI architecture
- **Workflow Compatibility**: Greenfield
- **Providers**: AWS (Bedrock integration)

## Module Standards

Each module includes:
- `main.tf` - Terraform resources
- `variables.tf` - Input variables with validation
- `outputs.tf` - Output values with descriptions
- `versions.tf` - Provider requirements
- `module.json` - BNK-Forge metadata for auto-wiring
- `README.md` - Documentation

## Usage

**Do not clone or modify this repository directly.**

Users interact through BNK-Forge UI:
1. Select modules from the catalog
2. Configure variables
3. BNK-Forge generates project in `bnk-forge-live`
4. Deploy with Terragrunt

## Reference Documentation

- [F5 Lifecycle Operator](https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/bnk-f5-lifecycle-operator.html)
- [BIG-IP Next for Kubernetes CRDs](https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/spk-custom-resources.html)
- [Gateway API](https://gateway-api.sigs.k8s.io/)

## Related Repositories

- **bnk-forge**: Main BNK-Forge application
- **bnk-forge-live**: User deployment projects

---

For more information, see the [BNK-Forge Documentation](https://github.com/JLCode-tech/bnk-forge)

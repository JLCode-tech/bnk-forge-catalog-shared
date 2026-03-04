# BNK-Forge Module Dependency Graph

This document maps all module dependencies and their input/output relationships for automated root.hcl generation.

## Module Layers (FLO-Based Architecture, BNK 2.2)

```
┌─────────────────────────────────────────────────────────────┐
│                   BNK Application Layer                      │
│        bnk-secpolicy, bnk-netpolicy, routes                 │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────┴──────────────────────────────────────┐
│                   BNK Gateway Layer                          │
│         gateway, bnk-gatewayclass, bnk-gateway-ext          │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────┴──────────────────────────────────────┐
│                   BNK Data Plane Layer                       │
│              cneinstance, bnk-vlans                          │
│    ┌─────────────────────────────────────────────────┐      │
│    │  CNEInstance triggers FLO to deploy:             │      │
│    │  CWC, DSSM, TMM, F5 Ingress, Fluentd, CRDs,    │      │
│    │  Observer, IPAM, RabbitMQ, OTEL, etc.           │      │
│    └─────────────────────────────────────────────────┘      │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────┴──────────────────────────────────────┐
│                   BNK Platform Layer                         │
│                         flo                                  │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────┴──────────────────────────────────────┐
│                   Kubernetes Layer                           │
│       bnk-prerequisites, cert-manager, network-setup        │
└──────────────────────┬──────────────────────────────────────┘
                       │
┌──────────────────────┴──────────────────────────────────────┐
│            Infrastructure Layer (AWS Example)                │
│    vpc → security → eks → storage → high-performance        │
└─────────────────────────────────────────────────────────────┘
```

## Key Architecture Change: FLO Manages BNK Components

As of BIG-IP Next for Kubernetes v2.1.0, the **F5 Lifecycle Operator (FLO)** automatically deploys and manages:

| Component | Previously | Now |
|-----------|------------|-----|
| CWC (Cluster Wide Controller) | Manual module | FLO auto-deploys |
| DSSM | Manual module | FLO auto-deploys |
| F5 Ingress | Manual module | FLO auto-deploys |
| Fluentd | Manual module | FLO auto-deploys |
| TMM | Manual module | FLO auto-deploys |
| CRDs (all) | Manual modules | FLO manages |
| Observer | Manual | FLO auto-deploys |
| IPAM Controller | Manual | FLO auto-deploys |
| RabbitMQ | Manual | FLO auto-deploys |

**Trigger**: When you apply a **CNEInstance** CR, FLO deploys all required BNK components (CWC, DSSM, TMM, etc.). The **GatewayClass** then tells the CNE controller which class of Gateways to manage.

## Detailed Module Dependencies

### Infrastructure Layer (AWS)

#### infra/aws/vpc
- **Layer**: Foundation
- **Dependencies**: None
- **Required Inputs**: project_name, environment, vpc_cidr, subnet_cidrs
- **Key Outputs**: vpc_id, vpc_cidr_block, subnet_ids, availability_zones
- **Required For**: security, eks, storage, high-performance-nodes

#### infra/aws/security
- **Layer**: Foundation
- **Dependencies**: vpc
- **Required Inputs**: vpc_id (from vpc), vpc_cidr_block (from vpc), public_subnet_id (from vpc), user_ip
- **Key Outputs**:
  - infrastructure_key_name
  - vpc_security_group_id
  - eks_cluster_role_arn
  - nodegroup_role_arn
  - jumphost_public_ip
  - oidc_provider_arn (conditional)
- **Required For**: eks, high-performance-nodes

#### infra/aws/eks
- **Layer**: Platform
- **Dependencies**: vpc, security
- **Required Inputs**:
  - vpc_id (from vpc)
  - private_external_subnet_ids (from vpc)
  - private_internal_subnet_ids (from vpc)
  - eks_cluster_role_arn (from security)
  - nodegroup_role_arn (from security)
  - vpc_security_group_id (from security)
  - infrastructure_key_name (from security)
- **Key Outputs**:
  - cluster_name
  - cluster_endpoint
  - cluster_certificate_authority_data
  - oidc_provider_arn
  - kubectl_config_command
- **Required For**: storage, high-performance-nodes, ALL k8s and BNK modules

#### infra/aws/storage
- **Layer**: Platform
- **Dependencies**: eks
- **Required Inputs**: cluster_name (from eks)
- **Key Outputs**: storage_classes_deployed, storage_class_names
- **Required For**: BNK modules requiring persistent storage

#### infra/aws/high-performance-nodes (v2.0.0)
- **Layer**: Platform
- **Dependencies**: vpc, security, eks
- **Required Inputs**:
  - vpc_id (from vpc)
  - cluster_name (from eks)
  - vpc_security_group_id (from security)
  - nodegroup_role_arn (from security)
  - key_pair_name (from security)
  - ecr_registry (user-provided)
- **Key Config**: f5_bnk_enabled (default: true), tmm_node_count (default: 1)
- **Key Outputs**: nodegroup_name, nodegroup_status, f5_bnk_readiness, summary
- **Deploys**: Multus CNI, SR-IOV device plugin, SR-IOV CNI, DPDK configurator, ENI attachment manager
- **Node Topology**: tmm_node_count nodes get app=f5-tmm + dpu=true:NoSchedule; rest untainted for BNK CP
- **Required For**: TMM pods (needs hugepages-2Mi, intel.com/external_netdevice, intel.com/internal_netdevice)

### Kubernetes Layer

#### k8s/bnk-prerequisites
- **Layer**: K8s Foundation (FIRST module in BNK stack)
- **Dependencies**: Kubernetes cluster
- **Required Inputs**:
  - cne_pull_secret (project secret — base64 F5 service account key)
  - bnk_manifest_version
- **Key Outputs**:
  - operator_namespace, utils_namespace, gateway_namespace
  - far_secret_name
  - flo_version (parsed from manifest)
  - prerequisites_ready
- **Required For**: cert-manager, flo, all BNK modules (namespace creation)

#### k8s/cert-manager
- **Layer**: K8s Foundation
- **Dependencies**: bnk-prerequisites (for FAR registry access)
- **Required Inputs**:
  - cluster_name
  - namespace
  - far_secret_name (from bnk-prerequisites)
  - cert_manager_version
- **Key Outputs**: cert_manager_ready, cluster_issuer_name
- **Required For**: flo (prerequisite for webhook certificates)

#### k8s/network-setup
- **Layer**: K8s Foundation
- **Dependencies**: Kubernetes cluster
- **Required Inputs**:
  - cluster_name
  - namespace
  - external_subnet_cidrs (from vpc or user-provided)
  - internal_subnet_cidrs (from vpc or user-provided)
- **Key Outputs**: external_nad_name, internal_nad_name
- **Required For**: cneinstance (network attachments for TMM pods)

### BNK Platform Layer

#### bnk/flo
- **Layer**: BNK Platform (Core Operator)
- **Dependencies**: bnk-prerequisites, cert-manager
- **Required Inputs**:
  - cluster_name
  - flo_namespace (from bnk-prerequisites)
  - flo_version (from bnk-prerequisites)
  - far_secret_name (from bnk-prerequisites)
  - cluster_issuer_name (from cert-manager)
  - cert_manager_ready (from cert-manager)
  - license_mode (connected|f5licenseproxy)
  - jwt_token (for licensing)
  - container_platform (Generic|AWS|Azure)
- **Key Outputs**:
  - flo_ready
  - flo_namespace
  - crds_installed
  - license_mode
- **Required For**: cneinstance, bnk-gatewayclass, gateway, routes, policies

### BNK Data Plane Layer

#### bnk/cneinstance
- **Layer**: BNK Data Plane
- **Dependencies**: flo, network-setup
- **Required Inputs**:
  - flo_ready (from flo)
  - namespace (from bnk-prerequisites.operator_namespace)
  - network_attachments (from network-setup)
- **Key Outputs**: instance_ready, network_attachments
- **Trigger**: Applying CNEInstance CR causes FLO to deploy all BNK components
- **Required For**: bnk-vlans, bnk-gatewayclass

#### bnk/bnk-vlans
- **Layer**: BNK Data Plane
- **Dependencies**: cneinstance
- **Required Inputs**:
  - namespace
  - external_self_ips, internal_self_ips
  - external_subnet_cidrs, internal_subnet_cidrs
  - aws_region (optional, enables ENI registration)
  - cneinstance_ready (from cneinstance)
- **Key Outputs**: vlans_ready, external_self_ips, internal_self_ips
- **Required For**: Gateway (TMM needs IPs before handling traffic)

### BNK Gateway Layer

#### bnk/bnk-gatewayclass
- **Layer**: BNK Gateway
- **Dependencies**: flo, cneinstance
- **Required Inputs**:
  - gatewayclass_name
  - flo_namespace (from flo — used to construct controllerName)
  - flo_ready (from flo)
  - instance_ready (from cneinstance)
- **Key Outputs**:
  - gatewayclass_name
  - gatewayclass_controller
  - gatewayclass_ready
- **Note**: Creates a standard GatewayClass (gateway.networking.k8s.io/v1). controllerName is auto-constructed as `f5.com/<namespace>-f5-cne-controller`.
- **Required For**: gateway

#### bnk/bnk-gateway-ext
- **Layer**: BNK Gateway
- **Dependencies**: flo
- **Required Inputs**:
  - gateway_ext_name (user)
  - flo_ready (from flo)
- **Optional Inputs**:
  - namespace
  - ipv4_cidr_range
  - ipv6_cidr_range
  - default_network
- **Key Outputs**: gateway_ext_name, gateway_ext_ready
- **Required For**: Optional IPAM integration with bnk/gateway

#### bnk/gateway
- **Layer**: BNK Gateway
- **Dependencies**: bnk-gatewayclass, flo
- **Required Inputs**:
  - cluster_name
  - gateway_name
  - gateway_namespace
  - gatewayclass_name (from bnk-gatewayclass)
  - gatewayclass_ready (from bnk-gatewayclass)
  - listeners (user-provided)
- **Optional Inputs**:
  - infrastructure_parameters_ref (from bnk-gateway-ext for IPAM)
  - gateway_addresses (static IPs)
- **Key Outputs**:
  - gateway_name
  - gateway_ready
  - gateway_addresses
- **Required For**: routes

### BNK Application Layer

#### bnk/routes
- **Layer**: BNK Application
- **Dependencies**: gateway
- **Required Inputs**:
  - cluster_name
  - route_name
  - route_namespace
  - gateway_name (from gateway)
  - gateway_ready (from gateway)
  - route_type (HTTPRoute, GRPCRoute, L4Route)
  - routing_rules (user-provided)
- **Key Outputs**: route_ready, route_name
- **Required For**: Application traffic routing

### BNK Policy Layer

#### bnk/bnk-secpolicy
- **Layer**: BNK Policy
- **Dependencies**: flo
- **Required Inputs**:
  - cluster_name
  - policy_name
  - policy_namespace
  - flo_ready (from flo)
  - security_settings (firewall, DDoS, rate limiting, ACL)
- **Key Outputs**: policy_ready
- **Required For**: Gateway/Route attachment (optional)

#### bnk/bnk-netpolicy
- **Layer**: BNK Policy
- **Dependencies**: flo
- **Required Inputs**:
  - cluster_name
  - policy_name
  - policy_namespace
  - flo_ready (from flo)
  - network_settings (TCP profiles, HTTP profiles, logging, persistence)
- **Key Outputs**: policy_ready
- **Required For**: Gateway/Route attachment (optional)

## Workflow Patterns

### Pattern 1: Full AWS + BNK Gateway API Stack (Recommended)
```
vpc → security → eks → storage → high-performance-nodes
  → bnk-prerequisites → cert-manager → network-setup
  → flo → cneinstance → bnk-vlans → bnk-gatewayclass → gateway → routes
                                                        └→ bnk-secpolicy
                                                        └→ bnk-netpolicy
```

### Pattern 2: Existing K8s + BNK Gateway API
```
(existing K8s) → bnk-prerequisites → cert-manager → network-setup → flo → cneinstance → bnk-vlans → bnk-gatewayclass → gateway → routes
```

### Pattern 3: Minimal BNK Deployment (no high-performance networking)
```
bnk-prerequisites → cert-manager → flo → cneinstance → bnk-gatewayclass → gateway → routes
```

### Pattern 4: BNK with High-Performance Nodes + Full Traffic Path
```
vpc → security → eks → high-performance-nodes
  → bnk-prerequisites → cert-manager → network-setup
  → flo → cneinstance → bnk-vlans → bnk-gatewayclass → bnk-gateway-ext → gateway → routes
```

## Entry Points by User Scenario

### Scenario A: "I have nothing, deploy everything on AWS"
**Entry Point**: vpc
**Full Chain**: vpc → security → eks → storage → high-performance-nodes → bnk-prerequisites → cert-manager → network-setup → flo → cneinstance → bnk-vlans → bnk-gatewayclass → gateway → routes

### Scenario B: "I have AWS EKS, add BNK"
**Entry Point**: bnk-prerequisites
**Chain**: bnk-prerequisites → cert-manager → network-setup → flo → cneinstance → bnk-vlans → bnk-gatewayclass → gateway → routes

### Scenario C: "I have Kubernetes (any provider), add BNK"
**Entry Point**: bnk-prerequisites
**Chain**: bnk-prerequisites → cert-manager → flo → cneinstance → bnk-gatewayclass → gateway → routes

### Scenario D: "I have FLO installed, configure traffic"
**Entry Point**: cneinstance
**Chain**: cneinstance → bnk-gatewayclass → gateway → routes

## Auto-Dependency Resolution Rules

1. **Required dependencies MUST be auto-included** (shown in error if not)
2. **Optional dependencies SHOULD be suggested** (user can skip)
3. **Infrastructure layer can be skipped** if user provides cluster access
4. **User selects entry point**, system resolves forward dependencies
5. **Backward dependencies auto-detected** from module metadata
6. **FLO is the central orchestrator** - selecting any Gateway API module requires FLO

## Archived Modules (Managed by FLO)

The following modules have been archived as they are now automatically deployed by FLO:

| Archived Module | Replaced By |
|-----------------|-------------|
| `bnk/cwc` | FLO auto-deploys |
| `bnk/dssm` | FLO auto-deploys |
| `bnk/fluentd` | FLO auto-deploys |
| `bnk/f5-controller` | FLO auto-deploys (F5 Ingress) |
| `bnk/crds/common` | FLO manages |
| `bnk/crds/deprecated` | FLO manages |
| `bnk/crds/service-proxy` | FLO manages |

See `archived/README.md` for details.

# BNK VLANs Module

## Overview

Creates F5SPKVlan custom resources that configure TMM data-plane interface IP addresses. TMM uses these self-IPs on its SR-IOV interfaces for external and internal traffic.

> **Key Concept:** NADs (Network Attachment Definitions) have no IPAM — TMM configures these IPs itself via the F5SPKVlan CR. On AWS, the module also registers self-IPs and VIPs as secondary IPs on the corresponding ENIs (required for Nitro ARP proxy).

## Features

- External and internal VLAN self-IP configuration
- Automatic prefix length derivation from subnet CIDRs
- CRD readiness wait (F5SPKVlan CRD installed by FLO at runtime)
- AWS ENI secondary IP registration (optional, cloud-only)
- Source/dest check disabled on ENIs for TMM traffic forwarding
- Auto-lasthop support for cloud deployments
- Programmed status verification with timeout

## Dependencies

- **CNEInstance**: BNK components must be deployed (FLO installs F5SPKVlan CRD)
- **Network Setup**: NADs must exist for TMM interfaces

## Usage

```hcl
module "bnk_vlans" {
  source = "./bnk/bnk-vlans"

  # Namespace (must match CNEInstance namespace)
  namespace = module.bnk_prerequisites.operator_namespace

  # Self IPs (one per TMM replica, from your subnet range)
  external_self_ips = ["10.0.10.240"]
  internal_self_ips = ["10.0.20.240"]

  # Subnet CIDRs (for prefix length derivation)
  external_subnet_cidrs = ["10.0.10.0/24"]
  internal_subnet_cidrs = ["10.0.20.0/24"]

  # AWS ENI registration (set aws_region to enable)
  aws_region         = "ap-southeast-2"
  gateway_vips       = ["10.0.10.100"]
  internal_subnet_id = module.vpc.private_internal_subnet_ids[0]

  # Auto-lasthop for cloud (prevents asymmetric routing)
  auto_lasthop = "AUTO_LASTHOP_ENABLED"

  # Dependency gate
  cneinstance_ready = module.cneinstance.instance_ready
}
```

## Interface Mapping

The F5SPKVlan interface numbers correspond to the order of network attachments in the CNEInstance:
- `1.1` = external (first NAD = external-netdevice)
- `1.2` = internal (second NAD = internal-netdevice)

## Inputs

| Name | Description | Type | Required | Default |
|------|-------------|------|----------|---------|
| cluster_name | Kubernetes cluster name | string | no | "" |
| namespace | Namespace for VLAN CRs | string | no | "f5-operator" |
| external_self_ips | External self IPs for TMM | list(string) | no | ["10.0.10.240"] |
| internal_self_ips | Internal self IPs for TMM | list(string) | no | ["10.0.20.240"] |
| external_subnet_cidrs | External subnet CIDRs | list(string) | no | ["10.0.10.0/24"] |
| internal_subnet_cidrs | Internal subnet CIDRs | list(string) | no | ["10.0.20.0/24"] |
| mtu | MTU for VLAN interfaces | number | no | 9000 |
| aws_region | AWS region (empty disables ENI registration) | string | no | "" |
| gateway_vips | VIPs to register on external ENI | list(string) | no | [] |
| internal_subnet_id | Internal subnet ID for ENI discovery | string | no | "" |
| auto_lasthop | Auto last-hop setting | string | no | "" |
| cneinstance_ready | Dependency gate from CNEInstance | bool | no | true |

## Outputs

| Name | Description |
|------|-------------|
| external_self_ips | External VLAN self IPs |
| internal_self_ips | Internal VLAN self IPs |
| vlans_ready | Gate — true when VLAN CRs are applied and programmed |

## Verification

```bash
# Check VLAN CRs
kubectl get f5spkvlan -n f5-operator

# Check Programmed status
kubectl get f5spkvlan -n f5-operator -o jsonpath='{range .items[*]}{.metadata.name}: {.status.conditions[?(@.type=="Programmed")].status}{"\n"}{end}'
```

## References

- [F5 Network Configuration](https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/bnk-configure-network.html)

## Module Metadata

- **Category**: bnk
- **Workflow Compatibility**: Greenfield, Partial
- **Version**: 2.2.0
- **Last Updated**: 2026-03-04

# F5 SPK VLAN Module

Creates F5SPKVlan custom resource for VLAN configuration with interfaces, self-IPs, MTU, and internal/external designation.

## Features

- **Interface Configuration**: Assign network interfaces to VLANs
- **Self-IP Management**: Configure IPv4 self-IP addresses
- **Internal/External**: Designate VLAN as internal or external
- **MTU Control**: Configure Maximum Transmission Unit
- **VLAN Tagging**: Optional 802.1Q VLAN ID

## Usage

```hcl
# External VLAN
module "external_vlan" {
  source = "bnk/f5spkvlan"

  cluster_name    = "prod-cluster"
  vlan_name       = "external-vlan-az-a"
  vlan_namespace  = "f5-spk"
  vlan_tag_name   = "external-az-a"

  flo_ready = module.flo.flo_ready

  interfaces     = ["1.1"]
  selfip_v4s     = ["172.16.100.200"]
  prefixlen_v4   = 23
  mtu            = 1380
  internal       = false
  vlan_id        = 100
}

# Internal VLAN
module "internal_vlan" {
  source = "bnk/f5spkvlan"

  cluster_name    = "prod-cluster"
  vlan_name       = "internal-vlan-az-a"
  vlan_namespace  = "f5-spk"
  vlan_tag_name   = "internal-az-a"

  flo_ready = module.flo.flo_ready

  interfaces     = ["1.2"]
  selfip_v4s     = ["172.16.104.200"]
  prefixlen_v4   = 23
  mtu            = 1380
  internal       = true
}
```

## Requirements

- FLO module deployed (provides F5SPKVlan CRD)
- Kubernetes cluster with F5 BNK 2.2 GA

## Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| cluster_name | string | yes | Name of the Kubernetes cluster |
| vlan_name | string | yes | Name for the VLAN resource |
| vlan_namespace | string | yes | Namespace for deployment |
| flo_ready | bool | yes | Dependency flag from FLO module |
| vlan_tag_name | string | yes | VLAN tag name (F5 config) |
| interfaces | list(string) | yes | Network interfaces |
| selfip_v4s | list(string) | yes | IPv4 self-IP addresses |
| prefixlen_v4 | number | yes | IPv4 prefix length (1-32) |
| internal | bool | yes | Internal or external VLAN |
| vlan_id | number | no | 802.1Q VLAN ID (1-4094) |
| mtu | number | no | Maximum Transmission Unit (default: 1500) |

## Outputs

| Name | Description |
|------|-------------|
| vlan_ready | Flag indicating VLAN is ready |
| vlan_name | Name of the created VLAN |
| vlan_namespace | Namespace where VLAN is deployed |
| vlan_type | VLAN type (internal or external) |
| selfip_addresses | Configured self-IP addresses |

## Interface Format

Interfaces are specified as strings: `"1.1"`, `"1.2"`, etc.

## Dependencies

- **Required**: bnk/flo (provides CRDs)

## Notes

- VLANs are typically deployed in f5-spk namespace
- External VLANs handle internet-facing traffic
- Internal VLANs handle cluster-internal traffic
- Self-IPs are used for routing between VLANs
- MTU can be adjusted for jumbo frames or AWS/Azure requirements
- Based on archived module at: /archived/bnk/f5-controller/manifests/vlans.yaml

# F5 IPAM Provider Module

Creates F5IPAMProvider custom resource for IP Address Management (IPAM) with configurable IP ranges and provider types.

## Features

- **IP Range Management**: Define pools of IP addresses for allocation
- **Provider Types**: Support for multiple IPAM backends
- **Automatic Allocation**: IPAM automatically assigns IPs to services
- **Integration**: Works with F5 BNK and Gateway API

## Usage

```hcl
module "ipam_provider" {
  source = "bnk/f5ipamprovider"

  cluster_name        = "prod-cluster"
  provider_name       = "ipam-provider"
  provider_namespace  = "f5-spk"

  flo_ready = module.flo.flo_ready

  ip_ranges = [
    "10.0.1.0/24",
    "10.0.2.10-10.0.2.50"
  ]

  provider_type = "f5-ipam"
}
```

## Requirements

- FLO module deployed (provides F5IPAMProvider CRD)
- Kubernetes cluster with F5 BNK 2.2 GA

## Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| cluster_name | string | yes | Name of the Kubernetes cluster |
| provider_name | string | yes | Name for the IPAM provider resource |
| provider_namespace | string | yes | Namespace for deployment |
| flo_ready | bool | yes | Dependency flag from FLO module |
| ip_ranges | list(string) | yes | IP ranges for IPAM |
| provider_type | string | no | Provider type (default: f5-ipam) |

## Provider Types

- **f5-ipam**: Built-in F5 IPAM (default)
- **infoblox**: Infoblox IPAM integration
- **external**: External IPAM provider

## IP Range Formats

- CIDR notation: `"10.0.1.0/24"`
- IP range: `"10.0.1.10-10.0.1.50"`
- Single IP: `"10.0.1.100"`

## Outputs

| Name | Description |
|------|-------------|
| provider_ready | Flag indicating provider is ready |
| provider_name | Name of the created provider |
| provider_namespace | Namespace where provider is deployed |
| provider_type | Configured provider type |
| ip_range_count | Number of IP ranges |

## Dependencies

- **Required**: bnk/flo (provides CRDs)

## Notes

- IPAM providers manage IP address allocation for services
- Typically deployed in f5-spk namespace
- Multiple IP ranges can be specified for different subnets
- Services can request IPs from IPAM automatically
- Essential for LoadBalancer services in on-premises clusters

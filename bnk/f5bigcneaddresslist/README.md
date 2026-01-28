# F5 CNE Address List Module

Creates F5BigCneAddresslist custom resource for managing IP address lists used in firewall policies and access control rules.

## Features

- **IP Address Management**: Define lists of IP addresses or CIDR ranges
- **Reusable**: Can be referenced by multiple firewall policies and security rules
- **Validation**: Ensures all addresses are valid IP/CIDR notation

## Usage

```hcl
module "trusted_networks" {
  source = "bnk/f5bigcneaddresslist"

  cluster_name     = "prod-cluster"
  list_name        = "trusted-networks"
  list_namespace   = "default"

  flo_ready = module.flo.flo_ready

  addresses = [
    "10.0.0.0/8",
    "172.16.0.0/12",
    "192.168.1.0/24"
  ]

  description = "Trusted internal networks"
}
```

## Requirements

- FLO module deployed (provides F5BigCneAddresslist CRD)
- Kubernetes cluster with F5 BNK 2.2 GA

## Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| cluster_name | string | yes | Name of the Kubernetes cluster |
| list_name | string | yes | Name for the address list resource |
| list_namespace | string | yes | Namespace for deployment |
| flo_ready | bool | yes | Dependency flag from FLO module |
| addresses | list(string) | yes | List of IP addresses or CIDR ranges |
| description | string | no | Address list description |

## Outputs

| Name | Description |
|------|-------------|
| list_ready | Flag indicating list is ready |
| list_name | Name of the created list |
| list_namespace | Namespace where list is deployed |
| address_count | Number of addresses in the list |

## Address Format

Addresses can be:
- Individual IP addresses: `192.168.1.1`
- CIDR ranges: `10.0.0.0/8`, `192.168.1.0/24`

## Dependencies

- **Required**: bnk/flo (provides CRDs)

## Notes

- Address lists can be referenced by F5BigFwPolicy and BNKSecPolicy resources
- Lists are namespace-scoped
- Can be shared across multiple policies in the same namespace
- Changes to addresses trigger policy updates

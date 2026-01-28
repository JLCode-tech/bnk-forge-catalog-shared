# F5 SPK SNAT Pool Module

Creates F5SPKSnatpool custom resource for managing SNAT (Source Network Address Translation) pools with IP ranges and pool members.

## Features

- **IP Ranges**: Define pools using IP ranges
- **Pool Members**: Specify individual IP addresses
- **Source NAT**: Provides SNAT for egress traffic

## Usage

```hcl
module "snat_pool" {
  source = "bnk/f5spksnatpool"

  cluster_name    = "prod-cluster"
  pool_name       = "prod-snat-pool"
  pool_namespace  = "f5-spk"

  flo_ready = module.flo.flo_ready

  ip_ranges = [
    "10.0.1.10-10.0.1.20",
    "10.0.1.30-10.0.1.40"
  ]

  pool_members = [
    "10.0.1.50",
    "10.0.1.51"
  ]
}
```

## Requirements

- FLO module deployed (provides F5SPKSnatpool CRD)
- Kubernetes cluster with F5 BNK 2.2 GA

## Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| cluster_name | string | yes | Name of the Kubernetes cluster |
| pool_name | string | yes | Name for the SNAT pool resource |
| pool_namespace | string | yes | Namespace for deployment |
| flo_ready | bool | yes | Dependency flag from FLO module |
| ip_ranges | list(string) | yes | IP addresses or ranges |
| pool_members | list(string) | no | Specific IP addresses |

## Outputs

| Name | Description |
|------|-------------|
| pool_ready | Flag indicating pool is ready |
| pool_name | Name of the created pool |
| pool_namespace | Namespace where pool is deployed |
| ip_range_count | Number of IP ranges configured |

## IP Range Format

- Individual IPs: `"10.0.1.10"`
- IP ranges: `"10.0.1.10-10.0.1.20"`

## Dependencies

- **Required**: bnk/flo (provides CRDs)

## Notes

- SNAT pools are referenced by F5SPKEgress resources
- Provides source NAT for outbound traffic
- Typically deployed in f5-spk namespace
- Pool members are distributed for source NAT operations

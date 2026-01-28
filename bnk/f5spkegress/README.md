# F5 SPK Egress Configuration Module

Creates F5SPKEgress custom resource for configuring egress traffic routing with SNAT pools and destination control.

## Features

- **Egress CIDR**: Define CIDR range for egress traffic
- **SNAT Pool**: Reference SNAT pool for source NAT
- **Destination Control**: Specify allowed destination ranges

## Usage

```hcl
module "prod_egress" {
  source = "bnk/f5spkegress"

  cluster_name      = "prod-cluster"
  egress_name       = "prod-egress"
  egress_namespace  = "f5-spk"
  egress_cidr       = "10.0.0.0/8"

  flo_ready = module.flo.flo_ready

  snat_pool_ref = module.snat_pool.pool_name

  allowed_destinations = [
    "0.0.0.0/0"  # Allow all destinations
  ]
}
```

## Requirements

- FLO module deployed (provides F5SPKEgress CRD)
- Kubernetes cluster with F5 BNK 2.2 GA

## Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| cluster_name | string | yes | Name of the Kubernetes cluster |
| egress_name | string | yes | Name for the egress resource |
| egress_namespace | string | yes | Namespace for deployment |
| flo_ready | bool | yes | Dependency flag from FLO module |
| egress_cidr | string | yes | CIDR range for egress traffic |
| snat_pool_ref | string | no | Reference to SNAT pool |
| allowed_destinations | list(string) | no | Allowed destination CIDRs |

## Outputs

| Name | Description |
|------|-------------|
| egress_ready | Flag indicating egress is ready |
| egress_name | Name of the created egress config |
| egress_namespace | Namespace where config is deployed |
| egress_cidr | Configured egress CIDR |

## Dependencies

- **Required**: bnk/flo (provides CRDs)
- **Optional**: bnk/f5spksnatpool (SNAT pool for source NAT)

## Notes

- Egress configurations control outbound traffic routing
- SNAT pools provide source NAT for egress traffic
- Allowed destinations can be used to restrict egress
- Typically deployed in f5-spk namespace

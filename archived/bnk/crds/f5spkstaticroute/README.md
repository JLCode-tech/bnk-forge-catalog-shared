# F5 SPK Static Route Module

Creates F5SPKStaticRoute custom resource for configuring static routes with destination networks, gateways, and interfaces.

## Features

- **Static Routing**: Define fixed routes for network traffic
- **Gateway Configuration**: Specify next-hop gateways
- **Interface Binding**: Optionally bind to specific interfaces
- **Route Metrics**: Control route preference with metrics

## Usage

```hcl
# Default route
module "default_route" {
  source = "bnk/f5spkstaticroute"

  cluster_name     = "prod-cluster"
  route_name       = "default-route"
  route_namespace  = "f5-spk"

  flo_ready = module.flo.flo_ready

  destination = "0.0.0.0/0"
  gateway     = "172.16.100.1"
  interface   = "external-vlan"
  metric      = 1
}

# Specific network route
module "internal_route" {
  source = "bnk/f5spkstaticroute"

  cluster_name     = "prod-cluster"
  route_name       = "internal-network"
  route_namespace  = "f5-spk"

  flo_ready = module.flo.flo_ready

  destination = "10.0.0.0/8"
  gateway     = "172.16.104.1"
  metric      = 10
}
```

## Requirements

- FLO module deployed (provides F5SPKStaticRoute CRD)
- Kubernetes cluster with F5 BNK 2.2 GA

## Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| cluster_name | string | yes | Name of the Kubernetes cluster |
| route_name | string | yes | Name for the static route resource |
| route_namespace | string | yes | Namespace for deployment |
| flo_ready | bool | yes | Dependency flag from FLO module |
| destination | string | yes | Destination network (CIDR) |
| gateway | string | yes | Gateway IP address |
| interface | string | no | Network interface |
| metric | number | no | Route metric (default: 1) |

## Outputs

| Name | Description |
|------|-------------|
| route_ready | Flag indicating route is ready |
| route_name | Name of the created route |
| route_namespace | Namespace where route is deployed |
| destination | Configured destination network |
| gateway | Configured gateway IP |

## Route Metrics

- Lower metrics are preferred
- Valid range: 1-255
- Default: 1 (highest priority)

## Dependencies

- **Required**: bnk/flo (provides CRDs)
- **Optional**: bnk/f5spkvlan (VLAN interfaces)

## Notes

- Static routes define routing table entries
- Typically deployed in f5-spk namespace
- Multiple routes can be configured for different destinations
- Interface binding is optional but recommended for multi-VLAN setups

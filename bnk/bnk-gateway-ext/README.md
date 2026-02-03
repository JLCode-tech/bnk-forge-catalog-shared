# BNK Gateway Extension Module (F5BnkGateway)

Configures F5BnkGateway Custom Resource for IPAM integration with BNK Gateway API.

## Description

This module creates an F5BnkGateway CR that defines IP address ranges for the F5 IPAM Controller. When a Gateway references this F5BnkGateway via `infrastructure.parametersRef`, the IPAM controller automatically allocates IP addresses from the configured ranges.

## Prerequisites

- FLO must be deployed (`bnk/flo` module) with IPAM operator enabled

## Usage

```hcl
module "bnk_gateway_ext" {
  source = "git::https://github.com/org/bnk-forge-modules.git//bnk/bnk-gateway-ext"

  gateway_ext_name = "app-bnkgateway"
  namespace        = "app-ns"
  ipv4_cidr_range  = "192.168.17.0/24"
  
  flo_ready = module.flo.flo_ready
}
```

Then reference in Gateway (via bnk/gateway module):

```hcl
module "gateway" {
  source = "..."
  
  infrastructure_parameters_ref = {
    name = module.bnk_gateway_ext.gateway_ext_name
  }
}
```

## Inputs

| Name | Description | Type | Required | Default |
|------|-------------|------|----------|---------|
| gateway_ext_name | Name for the F5BnkGateway | string | yes | - |
| namespace | Namespace for the resource | string | no | "default" |
| ipv4_cidr_range | IPv4 CIDR range for IPAM | string | no | "" |
| ipv6_cidr_range | IPv6 CIDR range for IPAM | string | no | "" |
| default_network | Network name for allocation | string | no | "default" |
| flo_ready | Dependency flag | bool | yes | - |

## Outputs

| Name | Description |
|------|-------------|
| gateway_ext_name | Name of created F5BnkGateway |
| gateway_ext_namespace | Namespace of the resource |
| gateway_ext_ready | Boolean indicating success |
| ipv4_cidr_range | Configured IPv4 CIDR |
| ipv6_cidr_range | Configured IPv6 CIDR |

## API Version

- **CRD API**: `k8s.f5net.com/v1`
- **Kind**: `F5BnkGateway`
- **F5 BNK Version**: 2.2 GA

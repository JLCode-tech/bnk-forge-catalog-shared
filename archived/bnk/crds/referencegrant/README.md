# Gateway API Reference Grant Module

Creates Gateway API ReferenceGrant custom resource to allow cross-namespace references between Gateway API resources (Gateways, Routes, Services).

## Features

- **Cross-Namespace References**: Enable Routes in one namespace to reference Gateways/Services in another
- **Security**: Explicit authorization required for cross-namespace references
- **Flexible**: Support multiple from namespaces and resource types

## Usage

```hcl
# Allow HTTPRoutes in app namespaces to reference Gateway in gateway-system
module "allow_routes_to_gateway" {
  source = "bnk/referencegrant"

  cluster_name     = "prod-cluster"
  grant_name       = "allow-app-routes"
  grant_namespace  = "gateway-system"  # Where the Gateway lives

  flo_ready = module.flo.flo_ready

  from_namespaces = [
    "app-namespace-1",
    "app-namespace-2"
  ]

  to_resources = ["Gateway"]

  # Optional: restrict to specific Gateway names
  to_resource_names = ["prod-gateway"]
}

# Allow HTTPRoutes to reference Services in another namespace
module "allow_routes_to_services" {
  source = "bnk/referencegrant"

  cluster_name     = "prod-cluster"
  grant_name       = "allow-backend-services"
  grant_namespace  = "backend-namespace"  # Where Services live

  flo_ready = module.flo.flo_ready

  from_namespaces = ["frontend-namespace"]
  to_resources    = ["Service"]
}
```

## Requirements

- FLO module deployed (provides ReferenceGrant CRD)
- Kubernetes cluster with F5 BNK 2.2 GA and Gateway API

## Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| cluster_name | string | yes | Name of the Kubernetes cluster |
| grant_name | string | yes | Name for the ReferenceGrant resource |
| grant_namespace | string | yes | Namespace containing referenced resources |
| flo_ready | bool | yes | Dependency flag from FLO module |
| from_namespaces | list(string) | yes | Namespaces allowed to reference resources |
| to_resources | list(string) | yes | Resource types that can be referenced |
| to_resource_names | list(string) | no | Specific resource names (empty = all) |

## Outputs

| Name | Description |
|------|-------------|
| grant_ready | Flag indicating grant is ready |
| grant_name | Name of the created grant |
| grant_namespace | Namespace where grant is deployed |
| from_namespaces | Allowed source namespaces |
| to_resources | Allowed resource types |

## Supported Resource Types

- **Gateway**: Gateway API Gateway resources
- **Service**: Kubernetes Service resources
- **HTTPRoute**: Gateway API HTTPRoute resources
- **GRPCRoute**: Gateway API GRPCRoute resources
- **TCPRoute**: Gateway API TCPRoute resources
- **TLSRoute**: Gateway API TLSRoute resources
- **UDPRoute**: Gateway API UDPRoute resources

## Dependencies

- **Required**: bnk/flo (provides CRDs)
- **Optional**: bnk/gateway (Gateway resources to reference)

## Notes

- ReferenceGrants are deployed in the namespace containing the referenced resources
- Without a ReferenceGrant, cross-namespace references are denied by default
- Grants are unidirectional (from -> to)
- Multiple grants can be created for different namespace pairs
- Critical for multi-tenant Gateway API setups

# F5 CNE Port List Module

Creates F5BigCnePortlist custom resource for managing port lists used in firewall policies and access control rules.

## Features

- **Port Management**: Define lists of ports or port ranges
- **Reusable**: Can be referenced by multiple firewall policies and security rules
- **Validation**: Ensures all ports are valid numbers or ranges

## Usage

```hcl
module "web_ports" {
  source = "bnk/f5bigcneportlist"

  cluster_name     = "prod-cluster"
  list_name        = "web-ports"
  list_namespace   = "default"

  flo_ready = module.flo.flo_ready

  ports = [
    "80",
    "443",
    "8080-8090"
  ]

  description = "Standard web service ports"
}
```

## Requirements

- FLO module deployed (provides F5BigCnePortlist CRD)
- Kubernetes cluster with F5 BNK 2.2 GA

## Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| cluster_name | string | yes | Name of the Kubernetes cluster |
| list_name | string | yes | Name for the port list resource |
| list_namespace | string | yes | Namespace for deployment |
| flo_ready | bool | yes | Dependency flag from FLO module |
| ports | list(string) | yes | List of ports or port ranges |
| description | string | no | Port list description |

## Outputs

| Name | Description |
|------|-------------|
| list_ready | Flag indicating list is ready |
| list_name | Name of the created list |
| list_namespace | Namespace where list is deployed |
| port_count | Number of ports/ranges in the list |

## Port Format

Ports can be:
- Individual ports: `"80"`, `"443"`, `"8080"`
- Port ranges: `"8000-8999"`, `"30000-32767"`

Valid port numbers: 1-65535

## Dependencies

- **Required**: bnk/flo (provides CRDs)

## Notes

- Port lists can be referenced by F5BigFwPolicy resources
- Lists are namespace-scoped
- Can be shared across multiple policies in the same namespace
- Changes to ports trigger policy updates

# BNK Namespaces Module

Creates the required Kubernetes namespaces for F5 BIG-IP Next for Kubernetes (BNK) deployment.

## Description

This module creates the standard namespaces required for a BNK deployment:

| Namespace | Default Name | Purpose |
|-----------|--------------|---------|
| BNK Core | `f5-bnk` | Core BNK components: FLO, CWC, TMM |
| Utilities | `f5-utils` | Utility components: IPAM, observability, dSSM |
| Gateway | `gateway-ns` | Gateway API resources: Gateway, routes, policies |

## Usage

```hcl
module "bnk_namespaces" {
  source = "git::https://github.com/JLCode-tech/bnk-forge-modules.git//k8s/bnk-namespaces?ref=release/2.2"

  # Use defaults for standard deployment
  bnk_namespace     = "f5-bnk"
  utils_namespace   = "f5-utils"
  gateway_namespace = "gateway-ns"
}
```

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `bnk_namespace` | Namespace for core BNK components | `string` | `"f5-bnk"` |
| `utils_namespace` | Namespace for utility components | `string` | `"f5-utils"` |
| `gateway_namespace` | Namespace for Gateway API resources | `string` | `"gateway-ns"` |
| `create_gateway_namespace` | Whether to create gateway namespace | `bool` | `true` |
| `create_far_secrets` | Whether to create FAR pull secrets | `bool` | `false` |
| `far_secret_name` | Name of FAR image pull secret | `string` | `"f5-far-secret"` |

## Outputs

| Name | Description |
|------|-------------|
| `bnk_namespace` | Name of the BNK core namespace |
| `utils_namespace` | Name of the utilities namespace |
| `gateway_namespace` | Name of the gateway namespace |
| `namespaces_ready` | Flag indicating namespaces are ready |

## References

- [F5 BNK CloudDocs](https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/)
- [F5 BNK Installation Guide](https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/bink-install.html)

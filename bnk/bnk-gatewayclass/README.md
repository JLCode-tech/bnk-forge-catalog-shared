# GatewayClass Module

## Overview

Creates a standard Kubernetes GatewayClass resource for F5 BIG-IP Next for Kubernetes (BNK 2.2). The GatewayClass defines the infrastructure class of Gateways managed by the F5 CNE controller.

> **BNK 2.2 Note:** This module creates a standard `gateway.networking.k8s.io/v1` GatewayClass. There is no `BNKGatewayClassConfig` CRD — TMM configuration is handled by the CNEInstance CR and Gateway infrastructure annotations.

## Features

- Standard Kubernetes Gateway API compliance (`gateway.networking.k8s.io/v1`)
- Auto-constructed `controllerName` based on FLO namespace
- Verification with `kubectl wait --for=condition=Accepted`
- Common label support for consistent resource tagging

## Dependencies

- **FLO**: F5 Lifecycle Operator must be installed (installs Gateway API CRDs)
- **CNEInstance**: BNK components must be deployed before GatewayClass can be accepted

## Usage

```hcl
module "bnk_gatewayclass" {
  source = "./bnk/bnk-gatewayclass"

  # GatewayClass name
  gatewayclass_name = "bnk-gatewayclass"

  # FLO namespace (used to construct controllerName)
  flo_namespace = module.flo.flo_namespace

  # Dependency gates
  flo_ready      = module.flo.flo_ready
  instance_ready = module.cneinstance.instance_ready

  common_labels = {
    environment = "production"
  }
}
```

## Controller Name

The `controllerName` is automatically constructed as:
```
f5.com/<flo_namespace>-f5-cne-controller
```

For example, if `flo_namespace = "f5-bnk"`, the controller name becomes:
```
f5.com/f5-bnk-f5-cne-controller
```

You can override this with the `controller_name` variable if needed.

## Inputs

| Name | Description | Type | Required | Default |
|------|-------------|------|----------|---------|
| cluster_name | Kubernetes cluster name | string | no | "" |
| gatewayclass_name | Name of the GatewayClass resource | string | no | "bnk-gatewayclass" |
| controller_name | Controller name override (auto-constructed if empty) | string | no | "" |
| flo_namespace | FLO namespace (used for controllerName construction) | string | yes | - |
| description | Description of the GatewayClass | string | no | "F5 BIG-IP Kubernetes Gateway" |
| flo_ready | Dependency gate from FLO module | bool | no | true |
| instance_ready | Dependency gate from CNEInstance module | bool | no | true |
| common_labels | Labels to apply to all resources | map(string) | no | {} |

## Outputs

| Name | Description |
|------|-------------|
| gatewayclass_name | Name of the GatewayClass resource |
| gatewayclass_controller | Controller name for this GatewayClass |
| gatewayclass_ready | Gate — true when GatewayClass is deployed |

## What Gets Created

This module creates a single resource:

1. **GatewayClass** (`gateway.networking.k8s.io/v1`) — cluster-scoped resource that references the F5 CNE controller

Subsequent Gateway resources reference this class:
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: my-gateway
spec:
  gatewayClassName: bnk-gatewayclass  # References this module's output
  listeners: [...]
```

## Verification

```bash
# Check GatewayClass status
kubectl get gatewayclass bnk-gatewayclass -o wide

# Verify it's accepted by the controller
kubectl get gatewayclass bnk-gatewayclass -o jsonpath='{.status.conditions}'
```

## Troubleshooting

**GatewayClass not Accepted:**
- Verify the CNE controller is running: `kubectl get pods -n <flo_namespace> -l app=f5-cne-controller`
- Check the controllerName matches: `kubectl get gatewayclass -o jsonpath='{.items[*].spec.controllerName}'`
- Review controller logs for errors

## References

- [F5 GatewayClass Documentation](https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/bnk-gateway-api-gatewayclass.html)
- [Gateway API Specification](https://gateway-api.sigs.k8s.io/concepts/api-overview/#gatewayclass)

## Module Metadata

- **Category**: bnk
- **Workflow Compatibility**: Greenfield, Partial
- **Version**: 2.2.0
- **Last Updated**: 2026-03-04

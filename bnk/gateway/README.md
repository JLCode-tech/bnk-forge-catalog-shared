# Gateway Module

## Overview

Creates a Gateway API Gateway instance that serves as the entry point for external traffic. Gateways configure listeners, addresses, and TLS termination for routing traffic to backend services.

## Features

- Standard Kubernetes Gateway API compliance (`gateway.networking.k8s.io/v1`)
- Multiple listener support (HTTP, HTTPS, TCP, UDP, TLS)
- TLS termination and passthrough
- IPAM integration via F5BnkGateway infrastructure parameters
- BNKSecPolicy and BNKNetPolicy attachment (security and network policies)
- TMM resource and replica overrides per-gateway
- Network attachment overrides for multi-NIC TMM pods
- Service type configuration (LoadBalancer, ClusterIP, NodePort)

## Dependencies

- **GatewayClass**: Must exist and be accepted by the F5 CNE controller
- **FLO**: For Gateway API CRDs (installed automatically)

## Usage

```hcl
module "gateway" {
  source = "./bnk/gateway"

  # Gateway configuration
  gateway_name      = "my-gateway"
  gateway_namespace = "gateway-ns"
  gatewayclass_name = module.bnk_gatewayclass.gatewayclass_name

  # Listeners
  listeners = [
    {
      name     = "http"
      protocol = "HTTP"
      port     = 80
      allowed_routes = {
        namespaces = {
          from = "Same"
        }
      }
    },
    {
      name     = "https"
      protocol = "HTTPS"
      port     = 443
      tls = {
        mode = "Terminate"
        certificate_ref = {
          name = "tls-secret"
        }
      }
    }
  ]

  # Optional: Static addresses or IPAM
  enable_ipam = true

  # Optional: Policy attachments (via BNKSecPolicy/BNKNetPolicy CRs)
  security_policy_refs = [
    {
      name = "firewall-policy"
      kind = "F5BigFwPolicy"
    }
  ]

  network_policy_refs = [
    {
      name = "irule-policy"
      kind = "F5BigCneIrule"
    }
  ]

  # Dependency gate
  gatewayclass_ready = module.bnk_gatewayclass.gatewayclass_ready
}
```

## Inputs

| Name | Description | Type | Required | Default |
|------|-------------|------|----------|---------|
| cluster_name | Kubernetes cluster name | string | yes | - |
| gateway_name | Gateway resource name | string | yes | - |
| gateway_namespace | Namespace for Gateway | string | yes | - |
| gatewayclass_name | GatewayClass name | string | yes | - |
| listeners | List of listener configurations | list(object) | yes | - |
| addresses | Static addresses for Gateway | list(object) | no | [] |
| enable_ipam | Enable IPAM for IP allocation | bool | no | true |
| infrastructure_parameters_ref | F5BnkGateway reference for IPAM | object | no | null |
| gateway_addresses | Static IP addresses | list(object) | no | [] |
| security_policy_refs | Security extensions for BNKSecPolicy | list(object) | no | [] |
| network_policy_refs | Network extensions for BNKNetPolicy | list(object) | no | [] |
| tmm_replicas | TMM replica override | number | no | null |
| tmm_resources | TMM resource override (cpu, memory, hugepages) | object | no | null |
| network_attachments | Network attachment overrides | any | no | null |
| service_type | Service type override | string | no | null |
| gatewayclass_ready | GatewayClass ready gate | bool | yes | - |
| common_labels | Labels for all resources | map(string) | no | {} |

## Outputs

| Name | Description |
|------|-------------|
| gateway_name | Gateway resource name |
| gateway_namespace | Gateway namespace |
| gateway_ready | Gate — true when Gateway is deployed |

## Listener Protocols

| Protocol | Description |
|----------|-------------|
| HTTP | Plain HTTP traffic |
| HTTPS | TLS-terminated HTTP traffic |
| TCP | Layer 4 TCP traffic |
| UDP | Layer 4 UDP traffic |
| TLS | TLS passthrough |

## TLS Configuration

### Terminate Mode (Default for HTTPS)
```hcl
tls = {
  mode = "Terminate"
  certificate_ref = {
    name      = "my-tls-secret"
    namespace = "cert-namespace"  # optional
  }
}
```

### Passthrough Mode
```hcl
tls = {
  mode = "Passthrough"
}
```

## Policy Attachments

BNK 2.2 uses **BNKSecPolicy** and **BNKNetPolicy** CRs (API group `gateway.k8s.f5net.com/v1alpha1`) to attach security and network extensions to Gateways:

```hcl
# Security policies (firewall, DDoS, logging)
security_policy_refs = [
  { name = "my-fw-policy", kind = "F5BigFwPolicy" }
]

# Network policies (iRules, TCP profiles)
network_policy_refs = [
  { name = "my-irule", kind = "F5BigCneIrule" }
]
```

## References

- [F5 Gateway Documentation](https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/bnk-gateway-api-gateway.html)
- [Gateway API Specification](https://gateway-api.sigs.k8s.io/concepts/api-overview/#gateway)

## Module Metadata

- **Category**: bnk
- **Workflow Compatibility**: Greenfield, Partial
- **Version**: 2.2.0
- **Last Updated**: 2026-03-04

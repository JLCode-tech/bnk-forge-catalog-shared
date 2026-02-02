# Archived Modules

These modules have been archived as they are now managed by the **F5 Lifecycle Operator (FLO)**.

## Why Archived?

As of BIG-IP Next for Kubernetes v2.1.0, FLO automatically deploys and manages the following components when you apply a `BnkGatewayClass` Custom Resource:

- **CWC** (Cluster Wide Controller)
- **DSSM** (Distributed Session State Manager)
- **Fluentd** (Logging)
- **F5 Ingress** (formerly f5-controller)
- **CRDs** (Custom Resource Definitions)
  - Common CRDs
  - Service Proxy CRDs
  - Deprecated CRDs
- **TMM** (Traffic Management Microkernel)
- **CRD Installer**
- **Observer**
- **AFM** (Application Firewall Module)
- **OTEL Collector**
- **RabbitMQ**
- **IPAM Controller**
- And more...

## Current Deployment Flow

Instead of deploying these components manually, use:

1. **cert-manager** - Deploy F5 cert-manager (prerequisite)
2. **far-setup** - Configure FAR image pull secrets (prerequisite)
3. **network-setup** - Configure Multus NADs (prerequisite)
4. **flo** - Deploy F5 Lifecycle Operator
5. **bnk-gatewayclass** - Apply BnkGatewayClass CR (triggers FLO to deploy all BNK components)
6. **gateway** - Create Gateway resources
7. **routes** - Create HTTPRoute/GRPCRoute/L4Route resources
8. **bnk-netpolicy** / **bnk-secpolicy** - Apply network and security policies

## Reference Documentation

- [F5 Lifecycle Operator](https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/bnk-f5-lifecycle-operator.html)
- [BIG-IP Next for Kubernetes CRDs](https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/spk-custom-resources.html)

## Archived Date

Initial archive: 2025-12-02
Updated: 2026-02-02

## Archived Modules

| Module | Reason | Archived Date |
|--------|--------|---------------|
| `cwc/` | FLO deploys CWC automatically | 2025-12-02 |
| `dssm/` | FLO deploys DSSM automatically | 2025-12-02 |
| `fluentd/` | FLO deploys Fluentd automatically | 2025-12-02 |
| `f5-controller/` | FLO deploys F5 Ingress automatically | 2025-12-02 |
| `crds/common/` | FLO manages CRD installation | 2025-12-02 |
| `crds/deprecated/` | FLO manages CRD installation | 2025-12-02 |
| `crds/service-proxy/` | FLO manages CRD installation | 2025-12-02 |
| `cneinstance/` | FLO handles CNE instance creation automatically via GatewayClass CR | 2026-02-02 |

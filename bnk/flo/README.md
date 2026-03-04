# F5 Lifecycle Operator (FLO) Module

## Overview

Deploys the F5 Lifecycle Operator (FLO) via Helm chart from F5 Artifact Registry (FAR). FLO is the core operator that manages the lifecycle of BIG-IP Next for Kubernetes components.

## What FLO Manages

When triggered by a CNEInstance + GatewayClass, FLO automatically deploys:
- **CWC** (Cluster-Wide Controller)
- **DSSM** (Distributed Session State Manager)
- **TMM** (Traffic Management Microkernel)
- **Observer**, **Fluentd**, **OTEL Collector**
- **RabbitMQ**
- **IPAM Controller** (if enabled)
- **All CRDs** (Gateway API, F5SPKVlan, BNKSecPolicy, BNKNetPolicy, etc.)

## Features

- Automatic CRD installation and management
- Integrated licensing (connected mode or F5 License Proxy)
- CPCL key download and application (JWT license verification)
- IPAM operator deployment
- Cloud-aware configuration (AWS, Azure, Generic)
- License secret cleanup for clean redeploys
- CRD adoption for destroy/redeploy cycles

## Dependencies

- **bnk-prerequisites**: Namespaces, FAR secrets, and FLO version from manifest
- **cert-manager**: ClusterIssuer for webhook certificates

## Usage

```hcl
module "flo" {
  source = "./bnk/flo"

  # Cluster configuration
  cluster_name = "my-eks-cluster"

  # Namespace (wired from prerequisites)
  flo_namespace = module.bnk_prerequisites.operator_namespace

  # FAR configuration (wired from prerequisites)
  far_secret_name = module.bnk_prerequisites.far_secret_name
  flo_version     = module.bnk_prerequisites.flo_version

  # Licensing
  license_mode = "connected"
  jwt_token    = var.f5_jwt_token  # sensitive — project secret

  # Certificate manager (wired from cert-manager)
  cluster_issuer_name = module.cert_manager.cluster_issuer_name
  cert_manager_ready  = module.cert_manager.cert_manager_ready

  # Platform (affects GRPC and cloud networking)
  container_platform = "AWS"  # Generic, AWS, or Azure
}
```

## Licensing Modes

### Connected Mode (Default)
Connects directly to F5 production licensing servers:
```hcl
license_mode = "connected"
jwt_token    = "your-jwt-token"
```

TEEM URLs are hardcoded to F5 production endpoints (`product.apis.f5.com`, `product-s.apis.f5.com`).

### F5 License Proxy Mode
Uses an on-premises license proxy:
```hcl
license_mode         = "f5licenseproxy"
f5_license_proxy_url = "https://your-license-proxy:8080"
```

## Inputs

| Name | Description | Type | Required | Default |
|------|-------------|------|----------|---------|
| cluster_name | Kubernetes cluster name | string | no | "" |
| flo_namespace | Namespace for FLO deployment | string | no | "f5-operator" |
| flo_version | FLO Helm chart version | string | no | "v1.198.4-0.1.36" |
| far_secret_name | FAR pull secret name | string | no | "far-secret" |
| jwt_token | JWT token for licensing (sensitive) | string | no | "" |
| license_mode | connected or f5licenseproxy | string | no | "connected" |
| f5_license_proxy_url | License proxy URL (proxy mode only) | string | no | "" |
| container_platform | Platform type: Generic, AWS, Azure | string | no | "Generic" |
| cluster_issuer_name | ClusterIssuer name from cert-manager | string | no | "bnk-ca-cluster-issuer" |
| cert_manager_ready | Dependency gate from cert-manager | bool | no | true |

## Outputs

| Name | Description |
|------|-------------|
| flo_namespace | Namespace where FLO is deployed |
| flo_ready | Gate — true when FLO is deployed and verified |
| crds_installed | Gate — true when FLO CRDs are installed |
| helm_release_name | Helm release name |
| helm_release_version | Helm chart version deployed |
| license_mode | Configured licensing mode |

## Deployment Order (BNK 2.2)

```
1. infra/aws/vpc
2. infra/aws/security
3. infra/aws/eks
4. infra/aws/storage
5. infra/aws/high-performance-nodes
6. k8s/bnk-prerequisites     ← namespaces, FAR secrets, manifest
7. k8s/cert-manager           ← TLS certificates
8. k8s/network-setup          ← Multus NADs
9. bnk/flo                    ← THIS MODULE (operator + CRDs)
10. bnk/cneinstance            ← triggers FLO to deploy BNK components
11. bnk/bnk-vlans              ← TMM data-plane IP configuration
12. bnk/bnk-gatewayclass       ← standard GatewayClass
13. bnk/gateway                ← Gateway instances
14. bnk/routes                 ← HTTPRoute / L4Route
```

## Notes

- FLO must be installed in a dedicated namespace (default: `f5-operator`)
- FLO automatically installs all required CRDs
- CRDs persist after FLO Helm uninstallation — the module handles CRD adoption on redeploy
- CPCL key is downloaded from F5 CloudDocs and applied to the FLO namespace
- Stale license secrets are cleaned on redeploy to prevent activation conflicts

## Verification

After deployment, verify FLO is running:
```bash
# Check FLO pods
kubectl get pods -n f5-operator

# Verify CRDs installed
kubectl get crd | grep -E "f5|gateway"

# Check license status
kubectl get secret licensestatus -n f5-operator -o jsonpath='{.data.licensestatus}' | base64 -d
```

## Troubleshooting

**FLO pod not starting:**
- Verify cert-manager is running: `kubectl get pods -n cert-manager`
- Check FAR secret exists: `kubectl get secret far-secret -n f5-operator`
- Review FLO logs: `kubectl logs -n f5-operator -l app=flo`

**License errors:**
- For connected mode: Verify JWT token is valid and not expired
- For proxy mode: Verify F5 License Proxy URL is accessible
- Check CPCL key: `kubectl get configmap cpcl-key-cm -n f5-operator -o yaml`

**CRD adoption errors on redeploy:**
- The module automatically re-labels CRDs for Helm adoption
- If Helm still errors, manually delete stale CRD annotations

## References

- [F5 Lifecycle Operator](https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/bnk-f5-lifecycle-operator.html)
- [BNK Installation Guide](https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/installing-bnk-dpu-using-f5-lifecycle-operator/installing/bnk-install-flo.html)
- [F5 Licensing Guide](https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/bnk-licensing.html)

## Module Metadata

- **Category**: bnk
- **Workflow Compatibility**: Greenfield, Partial, Minimal
- **Version**: 2.2.0
- **Last Updated**: 2026-03-04

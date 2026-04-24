# CNEInstance Module - BIG-IP Next for Kubernetes GA 2.2

Creates a CNEInstance custom resource for F5 BIG-IP Next for Kubernetes (BNK) Gateway API deployments.

## Overview

The CNEInstance CR is the primary resource for deploying BIG-IP Next for Kubernetes. It defines:
- Product type (BNK or CNF)
- Gateway API support
- Network attachments for data plane connectivity
- Container registry configuration
- Deployment sizing
- Certificate management

## Requirements

- FLO (F5 Lifecycle Operator) must be deployed first - provides the CNEInstance CRD
- Network Attachment Definitions (NADs) must exist for the specified network attachments
- Container registry access configured (with image pull secrets if private)
- cert-manager ClusterIssuer (optional, for certificate management)

## Usage

```hcl
module "cneinstance" {
  source = "bnk/cneinstance"

  cluster_name       = "my-eks-cluster"
  instance_name      = "bnk-instance"
  instance_namespace = "f5-bnk"

  # Required: BNK version
  manifest_version = "2.2.0"

  # Required: Container registry
  registry_uri       = "myregistry.example.com/f5-bnk"
  image_pull_secrets = ["f5-registry-secret"]

  # Required: Network attachments (NAD names)
  network_attachments = [
    "external-net",
    "internal-net"
  ]

  # Product configuration
  product_type        = "BNK"
  gateway_api_enabled = true

  # Sizing
  deployment_size = "Small"  # Small, Medium, Large, Max

  # Certificate management (optional)
  cluster_issuer = "letsencrypt-prod"

  # Demo mode (disables hugepages for testing)
  demo_mode = false

  # Dependency
  flo_ready = module.flo.flo_ready
}
```

## Inputs

| Name | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| cluster_name | string | yes | - | Name of the Kubernetes cluster |
| instance_name | string | yes | - | Name for the CNEInstance resource |
| instance_namespace | string | yes | - | Namespace for deployment |
| manifest_version | string | yes | - | BNK version to deploy (e.g., "2.2.0") |
| registry_uri | string | yes | - | Container registry URI |
| network_attachments | list(string) | yes | - | List of NAD names |
| product_type | string | no | "BNK" | Product type: BNK or CNF |
| gateway_api_enabled | bool | no | true | Enable Gateway API support |
| deployment_size | string | no | "Small" | Size: Small, Medium, Large, Max |
| cluster_issuer | string | no | "" | cert-manager ClusterIssuer name |
| image_pull_policy | string | no | "IfNotPresent" | Image pull policy |
| image_pull_secrets | list(string) | no | [] | Image pull secret names |
| demo_mode | bool | no | false | Enable demo mode |
| flo_ready | bool | yes | - | Dependency from FLO module |
| common_labels | map(string) | no | {} | Labels to apply |
| annotations | map(string) | no | {} | Annotations to apply |

## Outputs

| Name | Description |
|------|-------------|
| instance_name | Name of the created CNEInstance |
| instance_namespace | Namespace where deployed |
| instance_ready | Flag indicating deployment initiated |
| manifest_version | BNK version deployed |
| deployment_size | Configured deployment size |
| product_type | Product type (BNK/CNF) |
| gateway_api_enabled | Gateway API status |
| network_attachments | Network attachments used |

## Deployment Sizes

| Size | Description |
|------|-------------|
| Small | Minimal resources for development/testing |
| Medium | Moderate resources for small production |
| Large | Higher resources for production workloads |
| Max | Maximum resources for high-performance scenarios |

## Network Attachments

Network attachments reference Multus NetworkAttachmentDefinition (NAD) resources that provide:
- External/ingress network connectivity
- Internal/backend network connectivity
- Management network (optional)

NADs must be created before deploying CNEInstance (typically via the network-setup module).

## Dependencies

- **Required**: bnk/flo (provides CNEInstance CRD)
- **Required**: k8s/network-setup (provides NADs) - or manually created NADs

## tmm-init ConfigMap (kernel-mode static routes)

In kernel mode (the default `tmm_data_plane_mode`), the TMM pod's only kernel
default route is via the internal control-plane interface (`tmm`,
`169.254.0.254`). Kernel ICMP/TCP responses to a same-VPC client (e.g. a
jumphost) leak via that interface and never reach the client.

Set `tmm_init_enabled = true` and provide `tmm_init_routes` to render a
`tmm-init` ConfigMap in the operator namespace. TMM auto-mounts it at
`/opt/lib/tmm/` and reloads `user_conf.tcl` every 1s (via the `file_reload`
directive in `tmm_init.tcl`).

```hcl
module "cneinstance" {
  source = "../../../bnk/cneinstance"
  # ... other inputs ...

  tmm_init_enabled = true
  tmm_init_routes = [
    {
      destination = "10.0.1.0/24"        # jumphost / client subnet
      gateway     = "10.0.11.1"          # external subnet's AWS gateway
      description = "client subnet via external"
    },
    # Add more for backend pod CIDRs, TGW endpoints, etc.
  ]
}
```

For the multi-AZ TGW pattern (per-node gateway switch + GRE tunnel endpoints
per Doc 3 page 28-29), use `tmm_init_user_conf_tcl_raw` to pass the TCL
verbatim. For TMM init customizations (Diameter/GTP profiles, pools, bigdb
tweaks), use `tmm_init_extra_tcl` — appended after the default boilerplate.

This is **required** for kernel-mode AWS deployments to actually route
client traffic correctly. Per F5 Doc 3 (AWS Cloud Multi-AZ Network
Architecture Deployment Guide).

## Notes

- CNEInstance may take several minutes to fully deploy and become ready
- Check the status with: `kubectl get cneinstance -n <namespace>`
- Pods will be created in the same namespace as the CNEInstance
- Demo mode is useful for testing without SR-IOV/hugepages requirements

# F5 SPK Global Options Module

Creates F5SPKGlobalOptions custom resource for cluster-wide SPK configuration including crypto acceleration and hardware offload settings.

## Features

- **Crypto Acceleration**: Enable hardware crypto acceleration
- **Hardware Offload**: Configure network operation offloading
- **Cluster-Scoped**: Applies to entire cluster (no namespace)
- **Performance Tuning**: Optimize SPK performance settings

## Usage

```hcl
module "spk_global_options" {
  source = "bnk/f5spkglobaloptions"

  cluster_name = "prod-cluster"
  options_name = "spk-global-config"

  flo_ready = module.flo.flo_ready

  crypto_acceleration      = true
  hardware_offload_enabled = true

  hardware_offload_settings = {
    tcp_offload      = true
    checksum_offload = true
    segmentation     = true
  }
}
```

## Requirements

- FLO module deployed (provides F5SPKGlobalOptions CRD)
- Kubernetes cluster with F5 BNK 2.2 GA

## Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| cluster_name | string | yes | Name of the Kubernetes cluster |
| options_name | string | yes | Name for the global options resource |
| flo_ready | bool | yes | Dependency flag from FLO module |
| crypto_acceleration | bool | no | Enable crypto acceleration (default: true) |
| hardware_offload_enabled | bool | no | Enable hardware offload (default: true) |
| hardware_offload_settings | object | no | Hardware offload config |

## Hardware Offload Settings

```hcl
hardware_offload_settings = {
  tcp_offload      = true  # TCP processing offload
  checksum_offload = true  # Checksum calculation offload
  segmentation     = true  # Packet segmentation offload
}
```

## Outputs

| Name | Description |
|------|-------------|
| options_ready | Flag indicating options are ready |
| options_name | Name of the created options |
| crypto_acceleration_enabled | Crypto acceleration status |
| hardware_offload_enabled | Hardware offload status |

## Dependencies

- **Required**: bnk/flo (provides CRDs)

## Notes

- **CLUSTER-SCOPED**: This resource is not namespaced
- Only one F5SPKGlobalOptions should exist per cluster
- Changes affect all SPK instances cluster-wide
- Crypto acceleration requires hardware support
- Hardware offload improves network performance
- Typically deployed early in cluster setup (order: 50)

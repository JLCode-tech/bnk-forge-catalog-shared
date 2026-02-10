# Changelog

All notable changes to this module will be documented in this file.

## [2.1.0] - 2026-02-10

### Fixed — Bulletproof Deployment (Lessons from Live Cluster)

These fixes address two root causes discovered on aws-sydney-bnk-demo-cluster that
caused TMM to be stuck in Pending state on first deploy:

#### 1. EKS AMI GRUB Hugepages Persistence
**Root cause**: EKS AL2 AMI bootstrap regenerates `/boot/grub2/grub.cfg` AFTER userdata
runs, overriding `sed` modifications to `/etc/default/grub`. Hugepages params were lost.

**Fix**: Three-layer hugepages allocation in `compact_userdata.sh`:
- **Layer 1**: GRUB drop-in config (`/etc/default/grub.d/99-dpdk-hugepages.cfg`) — survives
  EKS bootstrap regeneration
- **Layer 2**: Runtime sysfs allocation — hugepages available immediately without reboot
- **Layer 3**: `dpdk-hugepages.service` systemd unit — ensures hugepages on every boot

#### 2. SR-IOV Device Plugin Race Condition
**Root cause**: SR-IOV device plugin deployed BEFORE DPDK configurator, so it scanned for
vfio-pci devices before they were bound. Result: 0 allocatable resources, TMM can't schedule.

**Fix**: Three-part ordering guarantee:
- **Terraform ordering**: DPDK configurator now deploys before SR-IOV device plugin
- **Init container**: `wait-for-vfio` init container on SR-IOV device plugin pods waits
  for `/dev/vfio/noiommu-*` devices to exist before starting the plugin
- **Readiness polling**: `wait_for_dpdk` resource polls DPDK DaemonSet readiness before
  deploying SR-IOV device plugin

### Changed
- Deployment order: DPDK configurator → SR-IOV device plugin (was reversed)
- SR-IOV device plugin image: `latest-amd64` → `v3.7.0-amd64` (pinned, reproducible)
- All DaemonSet wait resources: `sleep 60` → actual readiness polling with 5min timeout
- Module version bumped to 2.1.0

## [2.0.0] - 2026-02-10

### Breaking Changes
- Renamed `f5_spk_enabled` variable to `f5_bnk_enabled` (default: `true`)
- Renamed outputs: `high_perf_nodegroup_*` → `nodegroup_*`, `f5_spk_readiness` → `f5_bnk_readiness`
- Removed `node_taints` variable (taints now applied selectively, not at node group level)

### Added
- `tmm_node_count` variable (default: 1) — controls how many nodes get `app=f5-tmm` label + `dpu=true:NoSchedule` taint
- `configure_tmm_nodes` resource — selectively labels/taints TMM nodes after DaemonSets deploy
- `f5_bnk_readiness` output with TMM node topology info

### Fixed
- SR-IOV device plugin nodeSelector: `sriov-capable: "true"` → `node-type: high-performance` (was causing DESIRED=0)
- All 6 DaemonSet tolerations: `f5.com/spk-node` → `dpu` to match actual TMM node taint
- Removed node-group-level taints that blocked BNK control plane pods (dSSM, RabbitMQ, CWC, etc.)
- EKS userdata GRUB hugepages configuration (wasn't persisting through AMI boot)

### Changed
- Full SPK → BNK rename across variables, labels, outputs, scripts, systemd services, directories
- Module version bumped to 2.0.0 (breaking variable/output renames)

### Verified on Live Cluster
- aws-sydney-bnk-demo-cluster (EKS 1.28, ap-southeast-2)
- TMM pod Running 4/4 with hugepages-2Mi: 8Gi, intel.com/external_netdevice: 1, intel.com/internal_netdevice: 1

## [1.0.0] - 2025-11-19

### Added
- Initial release
- Core functionality
- Comprehensive README documentation
- Basic example usage

### Status
- ⚪ Not yet tested in production

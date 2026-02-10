# Changelog

All notable changes to this module will be documented in this file.

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

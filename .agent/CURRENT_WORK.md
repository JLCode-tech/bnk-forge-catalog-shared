# Current Work

> **KEEP LEAN**: Max 60 lines. Prune "Recently Completed" to last 7 days only.
> Move older items to `.agent/archive/` or delete. One-liner per task.

Last Updated: 2026-02-10

## Active Tasks
> Move task here when starting. Only one active at a time.

**None** - Module hardened. Ready for full stack E2E testing.

---

## Recently Completed (Last 7 Days)

### Bulletproof Module Fixes v2.1.0 (2026-02-10)
- ✅ 3-layer hugepages persistence: GRUB drop-in + sysfs runtime + systemd service
- ✅ SR-IOV timing race fix: DPDK deploys before SR-IOV device plugin + init container gate
- ✅ Pinned SR-IOV device plugin image to v3.7.0-amd64 (was mutable latest-amd64)
- ✅ All DaemonSet waits: sleep 60 → actual readiness polling with 5min timeout

### High-Performance Nodes Overhaul v2.0.0 (2026-02-10) — S22-001
- ✅ Comprehensive module rewrite: SPK → BNK rename, selective TMM node tainting
- ✅ Fixed SR-IOV device plugin nodeSelector (sriov-capable → node-type: high-performance)
- ✅ Fixed all 6 DaemonSet tolerations (f5.com/spk-node → dpu)
- ✅ Added tmm_node_count variable for selective TMM node configuration
- ✅ Live cluster: patched DaemonSets, set GRUB hugepages, rebooted nodes
- ✅ TMM pod Running 4/4 with hugepages-2Mi: 8Gi, SR-IOV resources: 1/1

### F5 BNK Complete Module Fixes (2026-02-09)
- ✅ cert-manager: Changed from F5 to Jetstack v1.16.1 per F5 BNK 2.2 GA docs
- ✅ cert-manager: Added ClusterIssuer creation for FLO/CNEInstance
- ✅ bnk-gatewayclass: Removed unused `controller_namespace` variable
- ✅ flo/module.json: Added `far_setup_complete` and `cluster_issuer_name` inputs

### Flagged for Testing
- ⚠️ BNKGatewayClassConfig (`gateway.f5.com/v1`) - Not documented in BNK 2.2; may not exist
- ⚠️ Network attachment names mismatch (network-setup vs bnk-gatewayclass defaults)

---

## Blockers
**None**

---

## Next Steps
1. Full BNK stack E2E test (deploy through bnk-forge UI)
2. Verify BNKGatewayClassConfig CRD exists after FLO install

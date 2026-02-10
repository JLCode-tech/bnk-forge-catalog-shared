# Current Work

> **KEEP LEAN**: Max 60 lines. Prune "Recently Completed" to last 7 days only.
> Move older items to `.agent/archive/` or delete. One-liner per task.

Last Updated: 2026-02-10

## Active Tasks
> Move task here when starting. Only one active at a time.

**None** — Full 14-module stack deployed successfully on live cluster.

---

## Recently Completed (Last 7 Days)

### Gateway Module Fixes + Full Stack Deploy (2026-02-10)
- ✅ bnk-gatewayclass: Removed fabricated BNKGatewayClassConfig CRD (doesn't exist in BNK 2.2)
- ✅ bnk-gatewayclass: Now uses standard GatewayClass with auto-constructed controllerName
- ✅ gateway: Fixed PolicyAttachment (doesn't exist) → BNKSecPolicy/BNKNetPolicy (gateway.k8s.f5net.com/v1alpha1)
- ✅ gateway: Fixed network_attachments type mismatch (tuple from cneinstance vs expected object)
- ✅ routes: Fixed L4Route API group (gateway.f5.com/v1alpha1 → gateway.k8s.f5net.com/v1)
- ✅ All 14 modules deployed and applied on aws-sydney-bnk-demo-cluster

### Bulletproof Module Fixes v2.1.0 (2026-02-10)
- ✅ 3-layer hugepages persistence: GRUB drop-in + sysfs runtime + systemd service
- ✅ SR-IOV timing race fix: DPDK deploys before SR-IOV device plugin + init container gate
- ✅ Pinned SR-IOV device plugin image to v3.7.0-amd64 (was mutable latest-amd64)
- ✅ All DaemonSet waits: sleep 60 → actual readiness polling with 5min timeout

### High-Performance Nodes Overhaul v2.0.0 (2026-02-10) — S22-001
- ✅ Comprehensive module rewrite: SPK → BNK rename, selective TMM node tainting
- ✅ Fixed SR-IOV device plugin nodeSelector + all 6 DaemonSet tolerations
- ✅ TMM pod Running 4/4 with hugepages-2Mi: 8Gi, SR-IOV resources: 1/1

---

## Blockers
**None**

---

## Known Issues (non-blocking)
- kubectl verification steps in null_resource provisioners fail (no kubeconfig in worker container) — cosmetic only, actual resources created via kubernetes provider
- GatewayClass controllerName is `f5.com/gateway-controller` (auto-wired from old default), should be `f5.com/f5-bnk-f5-cne-controller` — fix variable wiring in stack template

## Next Steps
1. Fix GatewayClass controllerName variable wiring in stack template
2. Verify GatewayClass is Accepted by CNE controller on cluster
3. Test end-to-end traffic flow through Gateway → HTTPRoute → backend service

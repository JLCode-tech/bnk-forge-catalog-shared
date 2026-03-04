# Current Work

> **KEEP LEAN**: Max 60 lines. Prune "Recently Completed" to last 7 days only.
> Move older items to `.agent/archive/` or delete. One-liner per task.

Last Updated: 2026-03-04

## Active Tasks
> Move task here when starting. Only one active at a time.

**None** — Documentation refresh complete. Ready to commit.

---

## Recently Completed (Last 7 Days)

### Documentation Refresh for release/2.2 (2026-03-04)
- ✅ Removed test TEEM URLs + license_environment variable from bnk/flo
- ✅ Terraform fmt across entire repo (infra/aws/ alignment fixes)
- ✅ Reverted archived/ changes (not needed on release branch)
- ✅ Rewrote bnk/flo/README.md — correct deployment order, removed test env refs
- ✅ Rewrote bnk/bnk-gatewayclass/README.md — removed fabricated BNKGatewayClassConfig, fixed SPK refs
- ✅ Rewrote bnk/gateway/README.md — BNKSecPolicy/BNKNetPolicy instead of PolicyAttachment
- ✅ Updated bnk/routes/README.md — L4Route API group table, version bump
- ✅ Created missing bnk/bnk-vlans/README.md
- ✅ Created missing k8s/bnk-prerequisites/README.md
- ✅ Rewrote root README.md — added all modules (cneinstance, vlans, prerequisites, gateway-ext, app/)
- ✅ Updated DEPENDENCY_GRAPH.md — added cneinstance/vlans/prerequisites layers, fixed workflow patterns

---

## Blockers
**None**

---

## Known Issues (non-blocking)
- kubectl verification in null_resource provisioners fails (no kubeconfig in worker container) — cosmetic
- GatewayClass controllerName needs variable wiring fix in stack template
- 7 module READMEs are still boilerplate stubs (far-setup, cert-manager, network-setup, eks, security, storage, high-performance-nodes)

## Next Steps
1. Commit documentation refresh changes
2. Fix GatewayClass controllerName variable wiring in stack template
3. Flesh out remaining boilerplate README stubs
4. Verify GatewayClass is Accepted by CNE controller on cluster

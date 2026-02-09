# Current Work

> **KEEP LEAN**: Max 60 lines. Prune "Recently Completed" to last 7 days only.
> Move older items to `.agent/archive/` or delete. One-liner per task.

Last Updated: 2026-02-09

## Active Tasks
> Move task here when starting. Only one active at a time.

**None** - Fixes committed, pending testing.

---

## Recently Completed (Last 7 Days)

### F5 BNK Complete Module Fixes (2026-02-09)
- ✅ cert-manager: Changed from F5 to Jetstack v1.16.1 per F5 BNK 2.2 GA docs
- ✅ cert-manager: Added ClusterIssuer creation for FLO/CNEInstance
- ✅ bnk-gatewayclass: Removed unused `controller_namespace` variable
- ✅ flo/module.json: Added `far_setup_complete` and `cluster_issuer_name` inputs

### Flagged for Testing
- ⚠️ BNKGatewayClassConfig (`gateway.f5.com/v1`) - Not documented in BNK 2.2; may not exist
- ⚠️ Network attachment names mismatch (network-setup vs bnk-gatewayclass defaults)

### Full System Testing (2026-02-09)
- 2 deploy/destroy cycles validated on remote server (AWS stack only)
- All modules working correctly
- Destroy retry loops added for timing issues

---

## Blockers
**None** - but F5 BNK Complete needs testing

---

## Before Ending Session
- [x] Update this file with progress
- [ ] Add decisions to `DECISIONS.md` if architectural
- [ ] Commit with proper message
- [ ] Document next steps

---

## Next Steps
1. Test F5 BNK Complete deployment end-to-end
2. Verify BNKGatewayClassConfig CRD exists after FLO install
3. If CRD missing, remove bnk-gatewayclass module (CNEInstance handles it)

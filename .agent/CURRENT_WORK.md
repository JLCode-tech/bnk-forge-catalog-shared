# Current Work - BNK-Forge Modules

Last Updated: 2026-02-09

## Active Tasks

> Tasks currently being worked on across agent sessions.
> **IMPORTANT**: When starting work on a task, move it here and add your session notes below.

**None currently - system is in tested stable state.**

---

## Recently Completed

### Full System Testing - Deploy/Destroy Validation (2026-02-09)

**Completed**: 2026-02-09
**Duration**: Multiple sessions
**Agent**: Claude (Opus 4.5)

**Description**:
Completed 2 full deploy/destroy cycles testing the entire BNK-Forge stack on remote server (192.168.1.96). All modules validated and working correctly.

**Test Results**:
- Fresh start script working correctly
- All infrastructure modules deploy successfully
- All destroy operations complete cleanly (with retry loops for timing issues)
- Module library sync from `release/2.2` branch working

**Key Fixes Applied During Testing**:
- `fix(infra): improve destroy cleanup with retry loops for timing issues`
- `fix(eks): add pre-create cleanup for orphaned KMS alias`
- `fix(eks): add KMS alias cleanup on destroy`
- `fix(infra): add cleanup for orphaned ENIs and EKS security groups`
- `fix(high-performance-nodes): replace kubectl with AWS CLI in provisioners`
- `fix(alembic): shorten migration filename to fix 32-char limit` (in bnk-forge-v2)

**Documentation Updates**:
- Updated README.md with version badges and tested status
- Added version compatibility table
- Added configuration instructions for module library branch

**Versions Tested**:
- bnk-forge-v2: 2.6.3
- bnk-forge-modules: release/2.2 branch
- Target: F5 BNK 2.2 GA

---

### P0: BNK 2.2 GA Alignment (2026-02-04 - 2026-02-08)

**Completed**: 2026-02-08
**Duration**: Multiple sessions
**Agent**: Claude (Opus 4.5)
**Implementation Plan**: `.agent/IMPLEMENTATION_PLAN_BNK_22_ALIGNMENT.md`

**Description**:
Aligned bnk-forge-modules and bnk-forge-v2 with F5 BIG-IP Next for Kubernetes 2.2 GA documentation.

**Implementation Stages Completed**:

| Stage | Task | Status |
|-------|------|--------|
| 1.1 | Restore `bnk/bnk-secpolicy` from archive, update to F5 2.2 schema | Completed |
| 1.2 | Restore `bnk/bnk-netpolicy` from archive, update to F5 2.2 schema | Completed |
| 1.3 | Create new `bnk/bnk-gateway-ext` for IPAM integration | Completed |
| 2.1 | Update `bnk/gateway` with IPAM support | Completed |
| 3.1 | Update DEPENDENCY_GRAPH.md | Completed |
| 3.2 | Update archived/README.md | Completed |
| 4 | Add CI validation workflow | Deferred |
| 5.1 | Update bnk-forge-v2 stack_templates.json | Completed |
| 5.2 | Resync catalog and test | Completed |

**Branching Strategy Implemented**:
- Created `release/2.2` branch for production use
- Future F5 versions get their own branches: `release/2.3`, `release/2.4`, etc.

---

## Recently Completed

### Archive F5 CRD Modules - FLO Installs CRDs Automatically (2026-02-03)

**Completed**: 2026-02-03
**Duration**: 1 session
**Agent**: Claude (Opus 4.5)

**Description**:
Archived 14 F5 CRD modules as FLO (F5 Lifecycle Operator) automatically installs and manages all F5 CRDs. This was discovered during remote server deployment testing of bnk-forge-v2.

**Modules Archived (14)**:
- `bnk/f5biganalyzer` → `archived/bnk/crds/`
- `bnk/f5bigcneaddresslist` → `archived/bnk/crds/`
- `bnk/f5bigcneportlist` → `archived/bnk/crds/`
- `bnk/f5bigfwpolicy` → `archived/bnk/crds/`
- `bnk/f5bigloghslpub` → `archived/bnk/crds/`
- `bnk/f5ipamprovider` → `archived/bnk/crds/`
- `bnk/f5spkegress` → `archived/bnk/crds/`
- `bnk/f5spkglobaloptions` → `archived/bnk/crds/`
- `bnk/f5spksnatpool` → `archived/bnk/crds/`
- `bnk/f5spkstaticroute` → `archived/bnk/crds/`
- `bnk/f5spkvlan` → `archived/bnk/crds/`
- `bnk/bnk-netpolicy` → `archived/bnk/crds/`
- `bnk/bnk-secpolicy` → `archived/bnk/crds/`
- `bnk/referencegrant` → `archived/bnk/crds/`

**Reason**:
Per F5 documentation (https://clouddocs.f5.com/bigip-next-for-kubernetes/latest/bnk-f5-lifecycle-operator.html):
> "FLO manages the lifecycle of Gateway API standard CRDs and F5 CRDs in a cluster, including installation, upgrade, and uninstallation."

These CRD modules were for creating *instances* of F5 CRDs for advanced post-deployment customization. Since:
1. FLO installs the CRDs automatically
2. These are advanced configs (not part of basic deployment)
3. Users can apply CRs manually via kubectl if needed

**12 Core Modules Remaining**:

| Category | Module | Purpose |
|----------|--------|---------|
| infra | vpc | AWS VPC with subnets |
| infra | eks | Amazon EKS cluster |
| infra | security | Security groups, IAM |
| infra | storage | S3, EFS storage |
| infra | high-performance-nodes | DPU/GPU node pools |
| k8s | cert-manager | TLS certificate management |
| k8s | network-setup | Multus CNI network attachments |
| bnk | far-setup | FAR image pull secrets |
| bnk | flo | F5 Lifecycle Operator |
| bnk | bnk-gatewayclass | BnkGatewayClass CR (triggers FLO) |
| bnk | gateway | Gateway API Gateway resources |
| bnk | routes | HTTPRoute, GRPCRoute, L4Route |

**Files Changed**:
- `archived/README.md` - Updated with archived modules
- 14 modules moved to `archived/bnk/crds/`

**Git Commit**: 3e8b83a

---

### PR Triage & Module Cleanup (2026-02-02)

**Completed**: 2026-02-02
**Duration**: 1 session
**Agent**: Claude (Opus 4.5)

**Description**:
Comprehensive PR triage and module cleanup to support deployment stacks in bnk-forge-v2. Closed 26 duplicate PRs, merged 8 unique PRs (security fixes + performance optimizations), and archived unused modules.

**PRs Closed as Duplicates (26)**:
- dpdk-devbind.py injection fixes: #44, #41, #37, #36, #33, #32, #30
- dpdk-devbind.py optimizations: #43, #40, #35, #34, #31, #29, #28, #24, #17, #13
- SR-IOV CNI security: #25, #23, #19, #18, #15, #14
- Other duplicates: #26, #20, #16

**PRs Merged (8)**:
| PR | Title | Type |
|----|-------|------|
| #21 | Fix command injection in dpdk-setup.sh | Sentinel CRITICAL |
| #27 | Remove insecure SR-IOV CNI installer script | Sentinel HIGH |
| #39 | Pin AWS CLI version in jumphost userdata | Sentinel HIGH |
| #45 | Pin amzn-drivers git clone in dpdk_userdata.sh | Sentinel CRITICAL |
| #46 | Optimize dpdk-devbind.py with native OS calls | Bolt + Security |
| #22 | Optimize SRIOV init script interface iteration | Bolt |
| #42 | Optimize network interface counting | Bolt |
| #38 | Optimize ENI attachment with polling | Bolt |

**Module Cleanup**:
- Archived `bnk/cneinstance` - FLO handles CNE instance creation automatically
- Removed empty `bnk/f5-controller` directory

**Key Outcomes**:
- Reduced open PRs from 34 to 0
- Security hardening: command injection fixes, dependency pinning, insecure downloads removed
- Performance improvements: ~138x speedup in dpdk-devbind.py, reduced node startup time
- Cleaner module library supporting deployment stacks

**Files Changed**:
- `infra/aws/high-performance-nodes/scripts/*` (security + performance)
- `infra/aws/security/templates/jumphost_userdata.sh` (AWS CLI pinning)
- `archived/README.md` (updated with cneinstance)
- `bnk/cneinstance/*` → `archived/bnk/cneinstance/*`

---

> Tasks completed in the last 30 days. Helps agents understand recent changes and context.

### Module Variable Cleanup - Remove Project-Level Variables (2026-01-20)

**Completed**: 2026-01-20
**Duration**: 1 session
**Agent**: Module Cleanup Agent

**Description**:
Cleaned up all module.json files by removing project-level variables that are automatically defined in root.hcl by bnk-forge. This eliminates duplication and confusion about what users actually need to configure.

**Variables Removed**:
- `project_name` - Defined in root.hcl (removed from infra/aws/vpc, security, eks, high-performance-nodes)
- `environment` - Defined in root.hcl (removed from infra/aws/vpc, security, eks, high-performance-nodes)
- `common_tags` - Defined in root.hcl (removed from all modules: infra/aws/vpc, security, eks, high-performance-nodes; k8s/cert-manager, network-setup; all bnk/ modules)

**Key Outcomes**:
- Removed 149 lines of duplicate variable declarations across 13 module.json files
- Only module-specific user inputs remain with "source": "user"
- Module dependency inputs remain with "source": "module"
- All module.json files validated and pass JSON syntax checks
- Terraform variables.tf files unchanged (they still declare these variables for Terragrunt inheritance)

**Files Changed**:
- `infra/aws/vpc/module.json` (removed project_name, environment, common_tags)
- `infra/aws/security/module.json` (removed project_name, environment, common_tags)
- `infra/aws/eks/module.json` (removed project_name, environment, common_tags)
- `infra/aws/high-performance-nodes/module.json` (removed project_name, environment, common_tags)
- `k8s/cert-manager/module.json` (removed common_labels)
- `k8s/network-setup/module.json` (removed common_labels)
- `bnk/far-setup/module.json` (removed common_labels)
- `bnk/flo/module.json` (removed common_labels)
- `bnk/bnk-gatewayclass/module.json` (removed common_labels)
- `bnk/gateway/module.json` (removed common_labels)
- `bnk/routes/module.json` (removed common_labels)
- `bnk/bnk-secpolicy/module.json` (removed common_labels)
- `bnk/bnk-netpolicy/module.json` (removed common_labels)

**Impact on bnk-forge**:
- root.hcl will only contain variables users actually need to edit
- Module-specific variables stay focused on what each module uniquely needs
- Dependency wiring (module outputs → inputs) remains clean and automatic
- No more EDIT_ME_PROJECT_NAME placeholders for project-level variables

**Notes for Future Work**:
- This cleanup supports the dependency wiring enhancement (ADR-006)
- When adding new modules, avoid adding project_name, environment, aws_region, common_tags to inputs
- Only add module-specific user inputs or module dependency inputs

---

### P0 Documentation: Module Dependency Wiring (2026-01-20)

**Completed**: 2026-01-20
**Duration**: 1 session
**Agent**: Documentation Agent

**Description**:
Documented the P0 critical task for module dependency and I/O wiring. While the implementation work happens in bnk-forge repository, this task captured the architectural decision, implementation plan, and backlog updates in bnk-forge-modules.

**Key Outcomes**:
- Added ADR-006 to DECISIONS.md documenting dependency wiring enhancement
- Updated BACKLOG.md with P0 task details and cross-repo context
- Created IMPLEMENTATION_PLAN_DEPENDENCY_WIRING.md with detailed 5-phase plan
- Committed and pushed all documentation updates (commit a73fc50)

**Files Changed**:
- `.agent/DECISIONS.md` (updated)
- `.agent/BACKLOG.md` (updated)
- `.agent/IMPLEMENTATION_PLAN_DEPENDENCY_WIRING.md` (created)
- `.agent/CURRENT_WORK.md` (this file)

**Notes for Future Work**:
- Phases 1-3 complete in bnk-forge repo (backend implementation)
- Phases 4-5 pending in bnk-forge repo (frontend UI + testing)
- module.json files in this repo already contain necessary metadata

---

### Setting Up Multi-Agent Workflow (2026-01-18)

**Completed**: 2026-01-18
**Duration**: 1 session
**Agent**: Setup Agent

**Description**:
Created comprehensive multi-agent workflow structure for bnk-forge-modules repository, adding agent coordination files and documentation to support multi-cloud expansion.

**Key Outcomes**:
- Created `.agent/` directory structure with coordination files
- Created CLAUDE.md with project overview and development guidelines
- Established documentation patterns for future agents
- Set up task tracking and decision recording system

**Files Changed**:
- `.agent/CLAUDE.md` (created)
- `.agent/CURRENT_WORK.md` (created)
- `.agent/BACKLOG.md` (created)
- `.agent/DECISIONS.md` (created)
- `.agent/PATTERNS.md` (created)
- Outcome 2
- Outcome 3

**Files Changed**:
- `path/to/file1`
- `path/to/file2`

**Notes for Future Work**:
- Follow-up items or things to watch

---

## Session Notes

> Quick notes for context sharing between agents. Add timestamps.

### 2026-01-18 - Initial Multi-Agent Setup

**What was done**:
- Analyzed repository structure
- Identified project as multi-cloud Terraform/Terragrunt module library
- Created `.agent/` and `.claude/skills/` directories
- Began creating agent coordination documentation

**Key Findings**:
- Repository uses Terraform modules with `module.json` metadata
- Three main categories: `infra/` (cloud-specific), `k8s/` (cloud-agnostic), `bnk/` (cloud-agnostic)
- Current production focus is AWS, with Azure/GCP/On-Prem planned
- Uses F5 Lifecycle Operator (FLO) v2.1.0+ for automated BNK deployment
- High-performance networking with SR-IOV, DPDK, Multus CNI

**Context for Next Agent**:
- This is a reference library that feeds into BNK-Forge tool
- Users don't clone this directly - they select modules via UI
- Module quality and documentation is critical - this is a product
- Security matters - infrastructure code affects production deployments
- Multi-cloud expansion is active - patterns should be cloud-agnostic where possible

---

## Blockers and Questions

> Issues preventing progress or questions needing user input.

**None currently**

---

## Handoff Checklist

Before ending your session, complete this checklist:

- [ ] Move completed tasks to "Recently Completed" section
- [ ] Update active tasks with current status and session notes
- [ ] Document any blockers or questions discovered
- [ ] Add any key findings to session notes
- [ ] Update `.agent/DECISIONS.md` with architectural choices made
- [ ] Update `.agent/PATTERNS.md` with new patterns introduced
- [ ] Update module documentation (README.md, module.json) if changed
- [ ] Update `DEPENDENCY_GRAPH.md` if dependencies changed
- [ ] Commit changes with proper commit message
- [ ] Ensure next steps are clearly documented
- [ ] Leave the repository in a clean state (no broken code)

---

## Task Entry Template

When adding new tasks, use this format:

```markdown
### Task Title (YYYY-MM-DD)

**Status**: Not Started | In Progress | Blocked | Completed
**Started**: YYYY-MM-DD
**Agent**: Agent identifier or session ID

**Description**:
Clear description of what needs to be done

**Session Notes**:
- Note 1
- Note 2

**Next Steps**:
- [ ] Step 1
- [ ] Step 2

**Files Modified**:
- `path/to/file`

**Related**:
- Links to DECISIONS.md entries
- Links to GitHub issues
- Links to related modules
```

---

## Notes

- Keep this file updated throughout your session, not just at the end
- The next agent depends on accurate information here
- When in doubt, add more context rather than less
- Use dates in YYYY-MM-DD format for consistency
- Link to other agent docs (DECISIONS.md, BACKLOG.md) when relevant

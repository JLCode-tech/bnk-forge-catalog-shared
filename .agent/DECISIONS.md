# Architecture Decisions

> **KEEP LEAN**: Max 80 lines. 2-3 lines per ADR max.
> Full context goes in code comments or separate docs, not here.

Last Updated: 2026-02-09

## Active Decisions

### ADR-001: Module Metadata (module.json)
Each module has `module.json` with name, version, inputs, outputs, dependencies.
Enables automated project generation. See `MODULE_METADATA_SCHEMA.md`.

### ADR-002: FLO as Deployment Method
F5 Lifecycle Operator manages BNK component deployment (CWC, DSSM, TMM).
Archived individual component modules. Flow: prerequisites → FLO → BnkGatewayClass.

### ADR-003: Three-Tier Organization
- `infra/` - Cloud-specific (VPC, clusters)
- `k8s/` - Cloud-agnostic K8s prereqs
- `bnk/` - Cloud-agnostic BNK components

### ADR-004: High-Performance Networking
SR-IOV + DPDK + Multus CNI + dedicated node pools for BNK performance requirements.

### ADR-005: Multi-Agent Workflow
`.agent/` directory for coordination: CLAUDE.md, CURRENT_WORK.md, BACKLOG.md, DECISIONS.md, PATTERNS.md.

### ADR-006: Dependency Wiring
module.json contains `dependencies.required[]`, `inputs[].from_module`, `outputs[].used_by`.
bnk-forge-v2 parses this for automatic wiring.

### ADR-007: No Project-Level Variables in module.json
Remove `project_name`, `environment`, `common_tags` from inputs - defined in root.hcl.
Keep only module-specific user inputs and module dependency inputs.

### ADR-008: Version-Based Branching
`release/X.Y` branches track F5 product versions (2.2, 2.3, etc.).
Main = latest stable. Tags: vX.Y.0.

### ADR-009: Policy Modules = CR Configuration
Policy modules create CR **instances**, not install CRDs. FLO handles CRDs.
Restored bnk-secpolicy, bnk-netpolicy from archive.

---

## Pending Decisions

### Azure/GCP Architecture
Open: Mirror AWS exactly vs use cloud-native patterns vs hybrid?
Needs research before implementing P1 multi-cloud modules.

### Module Versioning Strategy
Open: Semantic versioning in module.json vs git tags vs both?

---

## ADR Template
```markdown
### ADR-XXX: Title
**Date**: YYYY-MM-DD | **Status**: Accepted/Deprecated
**Decision**: What and why
**Consequences**: +/- outcomes
**Related**: files/modules
```

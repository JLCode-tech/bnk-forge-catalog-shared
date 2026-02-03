# Backlog - BNK-Forge Modules

Last Updated: 2026-02-04

## Overview

This backlog tracks prioritized work for the bnk-forge-modules repository. Items are organized by priority level and category. As this is a module library that feeds BNK-Forge, focus on module quality, cloud expansion, and developer experience.

## Priority Levels

- **P0 (Critical)**: Blockers, security issues, broken modules
- **P1 (High)**: New cloud platforms, major features, significant bugs
- **P2 (Medium)**: Enhancements, refactoring, documentation improvements
- **P3 (Low)**: Nice-to-haves, optimizations, future considerations

---

## P0 - Critical

### BNK 2.2 GA Alignment

#### Restore Policy Modules & Create IPAM Module
**Status**: Ready for Implementation
**Category**: BNK Modules
**Location**: `bnk/bnk-secpolicy`, `bnk/bnk-netpolicy`, `bnk/bnk-gateway-ext`, `bnk/gateway`

Stack templates in bnk-forge-v2 reference modules that were archived or don't exist. This breaks deployments.

**Problem**:
- `bnk/bnk-secpolicy` was archived but is referenced in stack templates
- `bnk/bnk-netpolicy` was archived but is referenced in stack templates
- `bnk/bnk-gateway-ext` doesn't exist (needed for F5BnkGateway IPAM)
- `bnk/gateway` needs IPAM support

**Key Insight**:
These modules create CR **instances** (not install CRDs). FLO installs CRDs automatically.
The archived modules were incorrectly categorized as "CRD installation" modules.

**Implementation Plan**: `.agent/IMPLEMENTATION_PLAN_BNK_22_ALIGNMENT.md`
**Related ADRs**: ADR-007 (branching), ADR-008 (CR vs CRD) in `.agent/DECISIONS.md`

**Tasks**:
1. Create `release/2.2` branch
2. Restore `bnk/bnk-secpolicy` from archive, update to F5 2.2 schema
3. Restore `bnk/bnk-netpolicy` from archive, update to F5 2.2 schema
4. Create new `bnk/bnk-gateway-ext` for IPAM integration
5. Update `bnk/gateway` with IPAM support
6. Update documentation (DEPENDENCY_GRAPH.md, archived/README.md)
7. Add CI validation workflow
8. Update bnk-forge-v2 stack templates

**Acceptance Criteria**:
- All modules pass `tofu validate`
- Stack templates reference existing modules
- "F5 BNK Complete" stack deploys end-to-end
- CI workflow validates on PR

**Estimated Time**: 3.5 hours

---

### Integration with bnk-forge-v2

#### Module Dependency Wiring (Cross-Repo)
**Status**: Largely Complete in bnk-forge-v2
**Category**: Integration
**Location**: Primarily bnk-forge-v2, data source is bnk-forge-modules

The module.json files contain rich dependency and I/O mapping data that bnk-forge-v2 uses.

**What bnk-forge-modules provides** (already exists):
- `dependencies.required[]` in module.json
- `inputs[].source: "module"` with `from_module`, `from_output`
- `outputs[].used_by` mappings
- `deployment.order` for correct sequencing

**What bnk-forge-v2 implements**:
1. ✅ Parse module.json during catalog sync
2. ✅ Use real dependencies from metadata
3. ✅ Wire outputs from dependencies to inputs
4. ✅ Show dependency status in UI
5. ⏳ Enhanced variable form (show user vs auto-wired)

**Implementation Plan**: `.agent/IMPLEMENTATION_PLAN_DEPENDENCY_WIRING.md`
**Related ADR**: ADR-006 in `.agent/DECISIONS.md`

---

## P1 - High Priority

### Multi-Cloud Expansion

#### Azure Infrastructure Modules
**Status**: Planned
**Category**: Infrastructure
**Location**: `infra/azure/` (new)

Create Azure equivalents of AWS infrastructure modules:
- `infra/azure/vnet` - Virtual Network with subnets
- `infra/azure/aks` - Azure Kubernetes Service
- `infra/azure/security` - Security groups and managed identities
- `infra/azure/storage` - Azure Storage Account, File Share
- `infra/azure/high-performance-nodes` - DPU/GPU node pools for AKS

**Acceptance Criteria**:
- Follow same module.json schema as AWS modules
- Support SR-IOV and accelerated networking
- Include comprehensive README with examples
- Add to DEPENDENCY_GRAPH.md

**Related**: DECISIONS.md (Azure architecture patterns)

---

#### GCP Infrastructure Modules
**Status**: Planned
**Category**: Infrastructure
**Location**: `infra/gcp/` (new)

Create GCP equivalents of AWS infrastructure modules:
- `infra/gcp/vpc` - VPC with subnets
- `infra/gcp/gke` - Google Kubernetes Engine
- `infra/gcp/security` - Firewall rules and service accounts
- `infra/gcp/storage` - Cloud Storage, Filestore
- `infra/gcp/high-performance-nodes` - High-performance node pools for GKE

**Acceptance Criteria**:
- Follow same module.json schema as AWS modules
- Support gVNIC for high-performance networking
- Include comprehensive README with examples
- Add to DEPENDENCY_GRAPH.md

**Related**: DECISIONS.md (GCP architecture patterns)

---

### Module Quality & Testing

#### Automated Module Validation
**Status**: Not Started
**Category**: CI/CD
**Location**: `.github/workflows/` (new)

Create GitHub Actions workflows for:
- Terraform validation (`terraform validate`)
- Terraform formatting check (`terraform fmt -check`)
- module.json schema validation
- README.md existence and structure check
- Dependency graph validation

**Acceptance Criteria**:
- All PRs must pass validation
- Runs on every commit to main
- Clear error messages for failures

---

## P2 - Medium Priority

### Module Enhancements

#### Advanced Gateway Configurations
**Status**: Not Started
**Category**: BNK Modules
**Location**: `bnk/gateway/`

Enhance gateway module to support:
- Multiple listeners per gateway
- Mixed protocol listeners (HTTP/HTTPS/TCP/UDP)
- Advanced TLS configuration options
- Custom gateway annotations

**Related**: `bnk/routes/` may need updates

---

#### High-Performance Nodes Optimization
**Status**: Not Started
**Category**: Infrastructure
**Location**: `infra/aws/high-performance-nodes/`

Optimize high-performance node configuration:
- Review DPDK setup scripts for efficiency
- Add SR-IOV auto-configuration improvements
- Optimize hugepage allocation
- Add monitoring and metrics collection

**Notes**: Current implementation works but could be more efficient

---

### Documentation

#### Module Development Guide
**Status**: Not Started
**Category**: Documentation
**Location**: `docs/` (new)

Create comprehensive guide for module developers:
- How to create new modules
- Module.json schema deep dive
- Testing and validation procedures
- Cloud-specific considerations
- Best practices and patterns

---

#### BNK Deployment Guide
**Status**: Not Started
**Category**: Documentation
**Location**: `docs/` (new)

Create end-to-end deployment guide:
- Prerequisites and planning
- Module selection strategy
- Deployment order and dependencies
- Troubleshooting common issues
- Migration from archived modules

---

## P3 - Low Priority

### Future Enhancements

#### On-Premises Kubernetes Support
**Status**: Idea
**Category**: Infrastructure
**Location**: `infra/on-prem/` (new)

Support for non-cloud Kubernetes deployments:
- Bare metal node configuration
- Local storage configuration
- Manual networking setup
- Integration with existing K8s clusters

**Notes**: Market demand unclear, needs research

---

#### Module Templates Improvement
**Status**: Idea
**Category**: Developer Experience
**Location**: `templates/`

Enhance module templates:
- Add cookiecutter-style templating
- Include common patterns as templates
- Add template for each cloud provider
- Script to generate new module from template

---

#### Cost Optimization Modules
**Status**: Idea
**Category**: Infrastructure
**Location**: Various

Add cost optimization features:
- Auto-scaling configurations
- Spot instance support
- Reserved instance recommendations
- Cost tagging strategies

---

## Vision & Planning

> Blue-sky ideas and long-term vision items. No immediate action required.

### Multi-Cluster BNK Deployments
Support BNK deployments spanning multiple Kubernetes clusters:
- Cross-cluster Gateway configuration
- Service mesh integration
- Multi-cluster traffic management

### Disaster Recovery Modules
Modules specifically for DR scenarios:
- Cross-region replication
- Backup and restore procedures
- Failover automation

### Compliance and Governance
Modules with built-in compliance:
- PCI-DSS configurations
- HIPAA-compliant setups
- SOC2 compliance patterns

---

## Completed

> Recently completed items for reference.

### Multi-Agent Workflow Setup (2026-01-18)
**Completed**: 2026-01-18
**Category**: Developer Experience

Created comprehensive agent coordination structure:
- `.agent/CLAUDE.md` - Main agent instructions
- `.agent/CURRENT_WORK.md` - Active task tracking
- `.agent/BACKLOG.md` - This file
- `.agent/DECISIONS.md` - ADR log
- `.agent/PATTERNS.md` - Code conventions
- `.claude/skills/` - Project-specific skills

**Impact**: Enables effective multi-agent collaboration on repository

---

## How to Use This Backlog

### For Agents

1. **Check Priority**: Start with P0, then P1, then P2
2. **Pick a Task**: Choose based on user request or highest priority
3. **Move to CURRENT_WORK**: When starting, move task to `.agent/CURRENT_WORK.md`
4. **Update Status**: Keep this file updated as work progresses
5. **Mark Complete**: Move to "Completed" section when done

### Adding New Items

Use this template:

```markdown
#### Task Title
**Status**: Not Started | In Progress | Blocked | Completed
**Category**: Infrastructure | K8s | BNK | Documentation | Developer Experience
**Location**: `path/to/files`

Brief description of the work needed.

**Acceptance Criteria**:
- Criterion 1
- Criterion 2

**Related**: Links to other docs, modules, or issues
**Notes**: Any additional context
```

### Prioritization Guidelines

- **P0**: Affects production users, security issues, or broken functionality
- **P1**: Expands platform capabilities, major features, or blocks future work
- **P2**: Improves existing functionality, quality, or developer experience
- **P3**: Nice to have, experimental, or unclear value

---

## Notes

- Keep this file organized and up-to-date
- Move items between priority levels as needed
- Add detail to items as you learn more
- Link to DECISIONS.md when architectural choices are involved
- Consider dependencies between items
- User requests always take priority over backlog

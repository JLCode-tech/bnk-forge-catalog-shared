# Backlog

> **KEEP LEAN**: Max 80 lines. Use bullet points, not paragraphs.
> Move completed items to CURRENT_WORK.md, then prune after 7 days.

Last Updated: 2026-02-09

## Priority Levels
- **P0**: Blockers, security, broken modules
- **P1**: New cloud platforms, major features
- **P2**: Enhancements, refactoring, docs
- **P3**: Nice-to-haves, future ideas

---

## P0 - Critical
**None** - BNK 2.2 alignment completed 2026-02-08

---

## P1 - High

### Azure Infrastructure Modules
**Location**: `infra/azure/` (new)
- vnet, aks, security, storage, high-performance-nodes
- Follow AWS module patterns
- Support SR-IOV and accelerated networking

### GCP Infrastructure Modules  
**Location**: `infra/gcp/` (new)
- vpc, gke, security, storage, high-performance-nodes
- Support gVNIC for high-performance networking

### Automated CI Validation
**Location**: `.github/workflows/`
- terraform validate, fmt check
- module.json schema validation
- README existence check

---

## P2 - Medium

### Advanced Gateway Configurations
- Multiple listeners per gateway
- Mixed protocol listeners
- Advanced TLS options

### High-Performance Nodes Optimization
- Review DPDK setup efficiency
- SR-IOV auto-configuration improvements
- Monitoring/metrics collection

### Documentation
- Module development guide
- BNK deployment guide

---

## P3 - Low
- On-premises K8s support
- Module template improvements (cookiecutter-style)
- Cost optimization features
- Multi-cluster BNK deployments
- DR modules
- Compliance modules (PCI-DSS, HIPAA, SOC2)

---

## Completed
See `CURRENT_WORK.md` for recent completions.
Historical: Multi-agent setup (2026-01-18), BNK 2.2 alignment (2026-02-08)

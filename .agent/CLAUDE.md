# Agent Instructions - BNK-Forge Modules

> **KEEP LEAN**: This file < 60 lines. Don't add verbose explanations.

## What This Is
Terraform/Terragrunt module library for BNK-Forge. Users select modules via UI → generates projects in `bnk-forge-live`.

**Stack**: Terraform 1.5+, Terragrunt, K8s 1.28+, AWS (prod) / Azure+GCP (planned), F5 BNK

## Quick Start
1. Read `CURRENT_WORK.md` → active tasks
2. Read `BACKLOG.md` → prioritized work  
3. Read `PATTERNS.md` → code conventions
4. Check `DECISIONS.md` if making architectural choices

## Structure
```
infra/aws/     # Cloud infra (VPC, EKS, security, storage, high-performance-nodes)
k8s/           # K8s prereqs (cert-manager, network-setup)
bnk/           # BNK components (flo, gateway, routes, policies)
archived/      # Deprecated modules
```

## Module Files (Required)
`main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `module.json`, `README.md`

## Workflow
1. Update `CURRENT_WORK.md` when starting
2. Follow `PATTERNS.md` for code style
3. Run `terraform validate` before committing
4. Update docs as you work (README, module.json)
5. Update `CURRENT_WORK.md` before ending

## Commits
Format: `<type>(<scope>): <subject>`
Types: feat, fix, docs, refactor, test, chore
Include: `Co-Authored-By: Claude <noreply@anthropic.com>`

## Validation
```bash
terraform fmt -check -recursive
terraform validate
find . -name "module.json" -exec jq empty {} \;
```

## MANDATORY: Version Bump on Every Push

**Every push to origin MUST include a version bump. No exceptions.**

- Bump revision in `VERSION` file (e.g. `2.2-rev.1` → `2.2-rev.2`)
- Format: `{BNK_VERSION}-rev.{N}` where N increments each push
- When a new `release/X.Y` branch is created, start at `X.Y-rev.1`

## Key Rules
- **Document as you work** - next agent depends on it
- **Security first** - no hardcoded secrets
- **Test changes** - always validate
- **Preserve compatibility** - don't break existing users
- **Update module.json** - keep metadata in sync
- **Bump VERSION** - every push, no exceptions

## Reference
- `DEPENDENCY_GRAPH.md` - module dependencies
- `MODULE_METADATA_SCHEMA.md` - module.json schema
- `archived/README.md` - why modules were archived
- `.agent/archive/` - completed implementation plans (historical)

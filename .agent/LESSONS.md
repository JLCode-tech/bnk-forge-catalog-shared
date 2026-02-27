# Lessons Learned

> **Agent memory file.** Updated when agents discover gotchas, pitfalls, or surprising behaviour.
> Loaded into context at session start. Prevents repeating the same mistakes.
> Keep under 80 lines. Group by category. Use `[severity]` tags.

Last Updated: 2026-02-26

---

## How to Use This File

Record **gotchas and pitfalls** so future sessions don't trip on the same things.
This file answers: "What surprised us? What should we watch out for?"

**When to write here:**
- A build/test fails for a non-obvious reason
- A library behaves differently than expected
- A configuration has a hidden requirement
- You spend >5 minutes debugging something preventable

**Format:**
```markdown
### [Category]

- [critical] **Title**: Description. Fix: what to do instead.
- [warning] **Title**: Description. Fix: what to do instead.
- [info] **Title**: Description.
```

**Severity:** `critical` = will break things | `warning` = wastes time | `info` = good to know

---

## Gotchas

<!-- Add entries as you discover them. Group by area. -->
<!-- Examples: -->

<!-- ### Configuration -->
<!--  -->
<!-- - [critical] **OpenCode limit.context**: Must be set on every model or auto-compaction never triggers. Session dies at context wall. Fix: Always include `"limit": { "context": 200000 }` in model config. -->
<!-- - [warning] **CLAUDE.md location**: Claude Code only reads CLAUDE.md from project root or .claude/CLAUDE.md — NOT from .agent/. Fix: Use setup.sh --framework claude to generate it. -->

<!-- ### Build & Deploy -->
<!--  -->
<!-- - [warning] **Docker build order**: COPY package*.json before COPY . to leverage layer caching. Fix: Always copy lockfiles first. -->

<!-- ### Testing -->
<!--  -->
<!-- - [info] **Flaky test on CI**: The auth timeout test occasionally fails under load. Retry once before investigating. -->

---

## Security

<!-- Security lessons learned from real projects. -->
<!-- Examples: -->
<!-- - [critical] **Never pass secrets via user_data**: Use Secrets Manager or SSM Parameter Store. -->
<!-- - [critical] **Pin binary versions + checksum verify**: Never curl | bash without pinning. -->
<!-- - [warning] **Pin git clones to commit hashes**: Tags can be moved. Use full SHA. -->
<!-- - [warning] **Validate all shell script inputs**: Use regex for integers/alphanumeric. No eval. -->

---

## Anti-Patterns Discovered

<!-- Things that seemed like a good idea but weren't. -->
<!-- Example: -->
<!-- - [warning] **Don't put everything in AGENTS.md**: Keep it under 50 lines. Move details to rules/ and context/. Large AGENTS.md wastes context tokens. -->

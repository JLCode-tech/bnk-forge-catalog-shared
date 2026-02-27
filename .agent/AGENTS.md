# Agent Instructions

> **KEEP LEAN**: This file < 50 lines. Details go in rules/ or context/.

## Startup
1. Read `CURRENT_WORK.md` — what's in progress right now
2. Read `MEMORY.md` — long-term project knowledge (facts, decisions, conventions, gotchas)
3. Check `backlog/BACKLOG.md` for `current:` item

## Backlog Workflow
1. If no `current:`, pick highest priority `ready` item
2. Update status to `in_progress`, set `current:`
3. Work until complete, then mark `done`, clear `current:`

## Memory Protocol (Two Layers)

**Short-term (in-session, survives compaction):**
- **TodoWrite**: Use for in-session task tracking — survives compaction natively
- **CURRENT_WORK.md**: Update every 2-3 tasks — progress, blockers, next steps

**Long-term (cross-session, curated):**
- **MEMORY.md**: Project facts, preferences, conventions index — the "working memory"
- **PATTERNS.md**: Code conventions, naming, file structure — update when conventions change
- **DECISIONS.md**: Architecture Decision Records (ADRs) — never delete, only supersede
- **LESSONS.md**: Gotchas, pitfalls, surprising behaviour — prevents repeating mistakes

**When to write memory:** When you discover a durable fact, learn a gotcha, make a decision, or
establish a convention. Use `[category]` tags: `[fact]`, `[decision]`, `[convention]`, `[gotcha]`, `[preference]`.

## Token Limit / Compaction
Auto-compaction handles most cases. If manual handoff needed:
Stop at checkpoint → create `handoff/HANDOFF.md` → commit → see `rules/handoff.md`

## Keep .agent/ Lean
- **MEMORY.md**: < 100 lines. Move stale items to `memory/archive/`.
- **BACKLOG.md**: Max 50 lines. Done items = one line.
- **HANDOFF.md**: Temporary. Delete after pickup.

## Project
See `context/project.md` for architecture. See `context/tech-stack.md` for stack.

## Rules
- **Quality**: Re-read `rules/code-quality.md` before writing code AND before committing
- **DRY**: Search before writing new code
- **Git**: Feature branches `agent/[item-id]`, never force push
- **Conflicts**: See `rules/conflicts.md` if touching shared files
- **Worktrees**: See `rules/worktrees.md` for multi-agent isolation
- **Archiving**: 100% complete + 3 days old + not referenced → `archive/`

# Handoff & Compaction Protocol

> **KEEP LEAN**: Max 40 lines.

## Auto-Compaction (Preferred)
Modern agents (Claude Code, OpenCode, Codex) compact automatically.
To survive compaction:
1. Use **TodoWrite** - task list persists through compaction
2. Write **CURRENT_WORK.md** every 2-3 tasks (progress, decisions, remaining)
3. Write **MEMORY.md** when you learn something durable (facts, gotchas, decisions)
4. **Commit often** - git is the ultimate persistence layer

## On Compaction Recovery
After compaction, the agent's context is reset to:
1. System prompt + AGENTS.md + memory files (always reloaded)
2. TodoWrite state (survives natively)
3. Compaction summary (auto-generated)

**First thing after compaction:** Read TodoWrite → Read CURRENT_WORK.md → Continue.

## Manual Handoff (Fallback)
Use when auto-compaction unavailable or agent hits hard limit.

### When
~180k tokens (OpenCode/Claude), ~100k (Cursor), 90% of limit (others)

### Steps
1. Stop at safe checkpoint (code compiles)
2. Keep `current:` set in backlog
3. Write `handoff/HANDOFF.md` (use template)
4. Update `CURRENT_WORK.md` with final state
5. Commit: `git commit -m "[agent] Checkpoint: [item-id]"`

## Pickup
1. Read handoff → CURRENT_WORK.md → MEMORY.md → AGENTS.md
2. `git status && npm install && npm test`
3. Continue from "Next step"
4. Delete HANDOFF.md after progress

## State Persistence Summary
| Layer | File | Survives | Purpose |
|-------|------|----------|---------|
| In-session | TodoWrite | Compaction | Task tracking |
| Short-term | CURRENT_WORK.md | Compaction + handoff | Active work state |
| Long-term | MEMORY.md | Everything | Project knowledge index |
| Long-term | PATTERNS.md | Everything | Code conventions |
| Long-term | DECISIONS.md | Everything | Architecture ADRs |
| Long-term | LESSONS.md | Everything | Gotchas + pitfalls |
| Permanent | Git commits | Everything | Code changes |

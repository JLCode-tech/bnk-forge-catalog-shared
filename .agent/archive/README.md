# Archive

> Historical records. Read-only. Never modify archived files.
> Agents may read these if they need historical context.

## Structure (created on-demand)
```
archive/
  sprints/     — Completed sprint trackers (mkdir -p when archiving)
  sessions/    — Session postmortems (mkdir -p when archiving)
  features/    — Completed feature plans (mkdir -p when archiving)
```

## Archive Policy
Items are archived when ALL conditions are met:
1. 100% complete (no open tasks or references)
2. 3+ days old (not actively referenced)
3. Not in active memory (not in CURRENT_WORK.md or BACKLOG.md)

See `rules/archive-policy.md` for full protocol.

## Failed Session Postmortems
When a session fails (bad approach, reverted work), archive it with:
- Root cause analysis (what went wrong and why)
- "DO NOT" rules (added to LESSONS.md)
- Proposed correct fix for next agent
- Files involved

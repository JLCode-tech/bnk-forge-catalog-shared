---
name: status
description: Quick project health check — git state, active work, backlog, tests
---

## What This Does

Run a quick health check to understand current project state.

## Steps

### 1. Git State
```bash
git status --short --branch
git log --oneline -5
```

### 2. Active Work
Read `.agent/CURRENT_WORK.md` — shows what was in progress last session.

### 3. Backlog
Read `.agent/backlog/BACKLOG.md` — shows the `current:` item and queued work.

### 4. Health Check
```bash
# Run lint (non-blocking)
npm run lint 2>&1 | tail -5 || echo "No lint script"
# Run tests (non-blocking)
npm test 2>&1 | tail -10 || echo "No test script"
```

### 5. Report
Summarize in a short status report:
- **Branch** + uncommitted changes count
- **Active task** from CURRENT_WORK.md (one line)
- **Backlog** count by priority (P0/P1/P2/P3)
- **Health** — tests pass? lint clean?
- **Recent commits** (last 3)

## Notes
- This is a **read-only** check. Don't fix issues, just report them.
- If no `.agent/` directory exists, report that setup hasn't been run.

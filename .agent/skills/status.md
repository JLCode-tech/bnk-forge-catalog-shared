# Skill: /status

## When to Use
Quick health check at session start, or when you need to understand current project state.

## What This Skill Does
1. Shows git state (branch, uncommitted changes, ahead/behind)
2. Shows active work from CURRENT_WORK.md
3. Shows backlog summary
4. Shows recent commits
5. Reports any issues (failing tests, lint errors)

## Step-by-Step Instructions

### 1. Git State
```bash
git status --short --branch
git log --oneline -5
```

### 2. Active Work
```bash
cat .agent/CURRENT_WORK.md 2>/dev/null || echo "No CURRENT_WORK.md"
```

### 3. Backlog Summary
```bash
cat .agent/backlog/BACKLOG.md 2>/dev/null || echo "No backlog"
```

### 4. Quick Health Check
```bash
# Run lint (non-blocking)
npm run lint 2>&1 | tail -5 || echo "No lint script"

# Run tests (non-blocking)
npm test 2>&1 | tail -10 || echo "No test script"
```

### 5. Report
Summarize findings in a short status report:
- Branch + uncommitted changes
- Active task (from CURRENT_WORK.md)
- Backlog count (P0/P1/P2/P3)
- Health: tests pass? lint clean?
- Recent activity (last 3 commits)

## Troubleshooting
- **No .agent/ directory**: Project hasn't been set up yet. Run `setup.sh`.
- **Tests fail**: Note failures in status report but don't fix (this is a read-only check).

## Related
- `.agent/CURRENT_WORK.md` — active work state
- `.agent/backlog/BACKLOG.md` — work queue
- `.agent/AGENTS.md` — full operating protocol

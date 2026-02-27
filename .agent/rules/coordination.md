# Multi-Agent Coordination

> **KEEP LEAN**: Max 40 lines.

## File Categories

| Category | Files | Rule |
|----------|-------|------|
| Safe | Feature directories | Edit freely |
| Shared | `package.json`, `docker-compose.yml`, config files | Pull first, commit immediately |
| Never | `package-lock.json`, `node_modules/` | Let npm manage |

## Parallel Work
Isolate by directory, feature, or layer. One agent per area.

## Dependencies
```bash
git pull origin main
npm install new-package
git add package.json package-lock.json
git commit -m "[agent] Add new-package"
git push
```

## Before Starting
```bash
git checkout main && git pull && git checkout -b agent/feature-name
```

## Before Committing
```bash
git fetch origin main && git rebase origin/main && npm test
```

## Worktree Isolation (Recommended for Parallel Agents)
When multiple agents work simultaneously, use git worktrees:
```bash
./scripts/setup-worktrees.sh    # Creates sibling directories
```
See `rules/worktrees.md` for full protocol.

## Empty Commit Signals (Multi-Agent)
```bash
git commit --allow-empty -m "[agent] WORKING ON: src/api/auth"
git commit --allow-empty -m "[agent] COMPLETE: auth refactor"
git commit --allow-empty -m "[agent] NEED SYNC: package.json"
```

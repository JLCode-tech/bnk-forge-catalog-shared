# Git Worktree Isolation

> **KEEP LEAN**: Max 60 lines. See scripts/setup-worktrees.sh for setup.

## When to Use
- Multiple agents need to work on the same repo simultaneously
- You need to isolate branches/builds to avoid file-level conflicts
- Long-running test suites that block other work

## How It Works
Each agent gets a **dedicated worktree** — a separate checkout of the same repo
in a sibling directory. All worktrees share `.git` but have independent working trees.

```
project/                    # Main checkout (main branch)
project-wt1/               # Worktree slot 1 (agent 1)
project-wt2/               # Worktree slot 2 (agent 2)
project-wt3/               # Worktree slot 3 (agent 3)
```

## Slot Protocol
1. Agent claims a slot (e.g., `wt1`) and notes it in `CURRENT_WORK.md`
2. Agent creates a feature branch from `origin/main`
3. Agent works independently — no shared branches
4. Agent pushes, creates PR, then resets the slot branch
5. Coordination happens via CURRENT_WORK.md noting which slot handles what

## Setup
```bash
# Create worktrees (run from main checkout)
./scripts/setup-worktrees.sh

# Or manually
git worktree add ../project-wt1 -b worktree/slot-1
git worktree add ../project-wt2 -b worktree/slot-2
```

## Per-Worktree Workflow
```bash
# In the worktree directory
git fetch origin
git checkout -b feat/my-feature origin/main

# Work, commit, push
git push -u origin feat/my-feature

# Reset slot when done
git checkout worktree/slot-1
git branch -D feat/my-feature
```

## Rules
- **Never share branches** between worktrees
- **Never modify shared files** (package-lock.json, docker-compose.yml) from multiple worktrees
- **Always fetch before branching** to avoid stale bases
- **Note your slot** in CURRENT_WORK.md so other agents/humans know who's where

## Teardown
```bash
./scripts/teardown-worktrees.sh
# Or manually: git worktree remove ../project-wt1
```

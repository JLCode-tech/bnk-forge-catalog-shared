# Starting AI Agents

## The Beginning Prompt

This is the **most important thing** — the first prompt you paste when starting an agent.
It tells the agent to read the boilerplate, use the memory system, and work autonomously.

### Recommended First Prompt (copy-paste this)

```
Read .agent/AGENTS.md and follow ALL instructions there.

Before starting any work:
1. Read .agent/CURRENT_WORK.md to understand what was happening last session
2. Read .agent/MEMORY.md for long-term project knowledge
3. Read .agent/LESSONS.md so you don't repeat past mistakes
4. Check .agent/backlog/BACKLOG.md for prioritised work items

As you work:
- Use TodoWrite to track your tasks (survives context compaction)
- Update .agent/CURRENT_WORK.md every 2-3 completed tasks
- When you learn something durable (a fact, gotcha, convention, or decision),
  write it to the appropriate memory file (MEMORY.md, PATTERNS.md, DECISIONS.md, or LESSONS.md)
- Commit frequently with conventional commit messages

Task: [Describe what you want to accomplish]
```

### Why This Works
- The agent reads ALL context before touching code
- Memory files give it "experience" from previous sessions
- TodoWrite + CURRENT_WORK.md ensure state survives compaction
- Writing back to memory files means future sessions get smarter
- The agent becomes more autonomous with each session

---

## Quick Start
```bash
cd /path/to/project

# Claude Code
claude

# OpenCode
opencode

# Codex CLI
codex
```

Then paste the beginning prompt above.

## Multi-Project
```bash
# From the ai-agent-setup directory (or set AGENT_WORKSPACE)
./launch-agents.sh
```

## After Handoff / Compaction
Most agents auto-compact and continue seamlessly. If manual handoff:

Run `start-agent.sh` — it detects pending handoffs automatically.

Or: `Continue from .agent/handoff/HANDOFF.md`

## Parallel Agents (Worktrees)
For true parallel work, use git worktrees so agents don't collide:
```bash
./scripts/setup-worktrees.sh   # Creates sibling directories
```
Then start one agent per worktree, each in its own terminal.

---

## Prompt Templates

**Standard** (with memory):
```
Read .agent/AGENTS.md and follow ALL instructions.
Read .agent/CURRENT_WORK.md and .agent/MEMORY.md for context.
Update memory files as you work. Task: [task]
```

**Autonomous backlog mode**:
```
Read .agent/AGENTS.md. Check .agent/CURRENT_WORK.md for previous state.
Read .agent/MEMORY.md and .agent/LESSONS.md for project knowledge.
Work through backlog/BACKLOG.md autonomously until empty.
Update CURRENT_WORK.md every 2-3 tasks. Write to LESSONS.md when you hit gotchas.
```

**Bug fix** (with history):
```
Read .agent/AGENTS.md. Check .agent/LESSONS.md for known gotchas.
Bug: [description] Expected: [x] Actual: [y]
Before fixing, check if this bug is already documented in LESSONS.md or DECISIONS.md.
```

**Isolated agent** (multi-agent):
```
Read .agent/AGENTS.md. I am Agent-[NAME], working ONLY in [DIR].
Read .agent/CURRENT_WORK.md — note which worktree slot I'm in.
Do not modify files outside my assigned directory. Task: [task]
```

**Architecture / planning**:
```
Read .agent/AGENTS.md. Read .agent/DECISIONS.md for prior architecture choices.
Review the codebase and propose architecture for [feature].
Write your plan to CURRENT_WORK.md before coding. Create an ADR in DECISIONS.md.
```

**Memory review** (before starting sensitive work):
```
Read .agent/MEMORY.md, .agent/LESSONS.md, and .agent/DECISIONS.md.
What gotchas, conventions, and architecture decisions should I know about
before working on [area]? Summarise the key points.
```

**New session continuation** (agent picks up where last left off):
```
Read .agent/AGENTS.md, then .agent/CURRENT_WORK.md.
Continue from where the last session left off.
Read .agent/MEMORY.md and .agent/LESSONS.md for accumulated knowledge.
Update CURRENT_WORK.md as you make progress.
```

# Agent Memory System

> Persistent memory that survives compaction, handoffs, and session boundaries.
> Design informed by [Anthropic's context engineering](https://docs.anthropic.com), [claude-mem](https://github.com/thedotmack/claude-mem),
> [Basic Memory](https://github.com/basicmachines-co/basic-memory), and the progressive disclosure pattern.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│  SHORT-TERM MEMORY (in-session, survives compaction)                │
│                                                                     │
│  TodoWrite          In-memory task list. Survives compaction        │
│                     natively. Agent reads it after compaction.      │
│                                                                     │
│  CURRENT_WORK.md    Scratchpad: active task, progress, blockers.    │
│                     Updated every 2-3 tasks. Read at session start. │
│                     Think: "what was I doing 5 minutes ago?"        │
│                                                                     │
│  Git commits        Ultimate persistence layer. Small, frequent.    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                              ↕
┌─────────────────────────────────────────────────────────────────────┐
│  LONG-TERM MEMORY (cross-session, curated, loaded at start)         │
│                                                                     │
│  MEMORY.md          Index of durable knowledge. Facts, decisions,   │
│                     conventions, gotchas, preferences. Uses         │
│                     [category] tags. < 100 lines.                   │
│                     Think: "what should I always know?"             │
│                                                                     │
│  PATTERNS.md        Code conventions. Naming, structure, imports,   │
│                     commit format. Updated when conventions change. │
│                     Think: "how do we do things here?"              │
│                                                                     │
│  DECISIONS.md       Architecture Decision Records. Never deleted,   │
│                     only superseded. ADR-NNN format.                │
│                     Think: "why did we choose X over Y?"            │
│                                                                     │
│  LESSONS.md         Gotchas and pitfalls. [severity] tags.          │
│                     Think: "what surprised us last time?"           │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
                              ↕
┌─────────────────────────────────────────────────────────────────────┐
│  SESSION ARCHIVE (on-demand, not loaded at start)                   │
│                                                                     │
│  memory/sessions/   Per-session logs. Auto-pruned after 14 days.   │
│                     Agent can grep these if it needs historical     │
│                     detail beyond what's in long-term memory.       │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Design Principles

### 1. Progressive Disclosure (from claude-mem)
Memory files are **indexes**, not dumps. MEMORY.md has one-line summaries pointing to
PATTERNS.md, DECISIONS.md, and LESSONS.md for full details. This keeps the context
budget lean — agents read titles first, then fetch details if needed.

### 2. Context as Currency (from Anthropic)
Every token loaded into context competes for attention. Our memory files are kept under
strict line limits (MEMORY.md < 100 lines, AGENTS.md < 50 lines) to maximize the
signal-to-noise ratio. Stale items are archived, not accumulated.

### 3. Structured Observations (from Basic Memory)
Memory entries use `[category]` tags for semantic clarity:
- `[fact]` — durable project truth
- `[decision]` — architecture choice (points to ADR)
- `[convention]` — established pattern (points to PATTERNS.md)
- `[gotcha]` — pitfall to avoid (points to LESSONS.md)
- `[preference]` — user/team preference
- `[critical]` / `[warning]` / `[info]` — severity for gotchas

### 4. Curated, Not Append-Only
Unlike auto-capture systems (claude-mem, opencode-mem), our Tier 1 memory is
**agent-curated**. The agent decides what's worth remembering. This avoids context
pollution but requires the agent to actively write to memory files.

### 5. Two-Layer Persistence
Short-term memory (TodoWrite + CURRENT_WORK.md) handles within-session state.
Long-term memory (MEMORY.md + PATTERNS/DECISIONS/LESSONS) handles cross-session knowledge.
Both survive compaction; only long-term survives across sessions.

## Memory Lifecycle

### Session Start
```
Agent loads:
1. AGENTS.md          → Instructions + memory protocol
2. CURRENT_WORK.md    → What was in progress (short-term)
3. MEMORY.md          → Project knowledge index (long-term)
4. PATTERNS.md        → Conventions (long-term, via instructions)
5. DECISIONS.md       → ADRs (long-term, via instructions)
6. LESSONS.md         → Gotchas (long-term, via instructions)
```

### During Work
```
Agent writes:
- TodoWrite           → Track tasks (every new task)
- CURRENT_WORK.md     → Progress update (every 2-3 tasks)
- Git commits          → Code changes (frequently)
```

### On Discovery (when the agent learns something new)
```
Agent writes:
- MEMORY.md           → One-line index entry with [category] tag
- PATTERNS.md         → If it's a convention
- DECISIONS.md        → If it's an architecture decision (ADR)
- LESSONS.md          → If it's a gotcha or pitfall
```

### Session End / Handoff
```
Agent writes:
- CURRENT_WORK.md     → Final state (status, remaining, context)
- memory/sessions/    → Session log (optional, YYYY-MM-DD-HH.md)
- Git commit           → All memory files
```

### Weekly Maintenance
```
Human or agent:
- Prune MEMORY.md     → Archive stale items to memory/archive/
- Prune LESSONS.md    → Remove fixed gotchas
- Review DECISIONS.md → Supersede outdated ADRs
```

## Configuration

### OpenCode (opencode.json)
```jsonc
{
  "instructions": [
    ".agent/AGENTS.md",
    ".agent/CURRENT_WORK.md",
    ".agent/MEMORY.md",
    ".agent/PATTERNS.md",
    ".agent/DECISIONS.md",
    ".agent/LESSONS.md"
  ]
}
```

### Claude Code (CLAUDE.md)
```markdown
Read these files at session start for persistent memory:
- @.agent/AGENTS.md (instructions + memory protocol)
- @.agent/CURRENT_WORK.md (active work state)
- @.agent/MEMORY.md (long-term project knowledge)
- @.agent/PATTERNS.md (code conventions)
- @.agent/DECISIONS.md (architecture decisions)
- @.agent/LESSONS.md (gotchas and lessons learned)
```

### Codex CLI
Codex reads AGENTS.md natively. Place a copy at project root or ensure
`.agent/AGENTS.md` is accessible.

## Upgrading to Tier 2+

### Claude-Mem (Tier 2) — Auto-Capture for Claude Code

```bash
/plugin marketplace add thedotmack/claude-mem
/plugin install claude-mem
```

**What it adds over Tier 1:**
- Hook-based auto-capture (no manual writing)
- AI-compressed observations with semantic summaries
- Full-text search (FTS5) across all sessions
- Progressive disclosure with token cost visibility
- Web viewer at localhost:37777
- MCP search tools (search → timeline → get_observations)

### OpenCode-Mem (Tier 3) — Semantic Search

```bash
opencode plugin install opencode-mem
```

**What it adds:** Vector embeddings for semantic search, auto user profile
learning, unified memory-prompt timeline, web UI at localhost:4747.

### OpenMemory (Tier 4) — Team Shared Memory

```bash
docker run -p 8080:8080 caviraoss/openmemory
# Claude Code: claude mcp add --transport http openmemory http://localhost:8080/mcp
# OpenCode: "mcp": { "openmemory": { "type": "http", "url": "http://localhost:8080/mcp" } }
```

**What it adds:** Hierarchical memory sectors (procedural, semantic, episodic),
salience scoring, reinforcement, team-shared via MCP.

### Basic Memory (Tier 5) — Knowledge Graph

```bash
pip install basic-memory
basic-memory serve
```

**What it adds:** Markdown → knowledge graph with relations, MCP tools,
observation types, bi-directional `[[WikiLinks]]`, Obsidian-compatible.

## FAQ

**Q: Do all memory files get loaded into every session?**
A: Yes, if configured in `instructions` (OpenCode) or `CLAUDE.md` (Claude Code).
That's why we enforce line limits — memory files are part of your context budget.

**Q: Won't memory files grow too large?**
A: That's why we curate, not append. Agents should prune stale items weekly.
Archive to `memory/archive/` or `memory/sessions/`. Target: MEMORY.md < 100 lines.

**Q: Why not just use CLAUDE.md for everything?**
A: CLAUDE.md is for instructions. Memory files separate *what to know* from
*what to do*. This keeps AGENTS.md lean (< 50 lines) and memory searchable.

**Q: Can I use this alongside claude-mem or Basic Memory?**
A: Yes. Tier 1 (file-based) is the foundation. Higher tiers add auto-capture
and search on top. You don't need to choose — they complement each other.

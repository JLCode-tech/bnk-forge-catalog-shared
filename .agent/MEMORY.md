# Memory

> **Long-term memory for agents.** Curated, not append-only.
> Agents: READ this at session start. WRITE to it when you learn something durable.
> Keep under 100 lines. Move stale items to `memory/archive/`.

Last Updated: 2026-02-26

---

## How to Use This File

This is the **index** of project knowledge. Think of it as the agent's "working memory"
that loads at the start of every session. It follows the **progressive disclosure** pattern:
titles here are concise; details live in PATTERNS.md, DECISIONS.md, and LESSONS.md.

**When to write here:**
- You discover a durable fact about the project
- A user states a preference or convention
- You make an architectural decision
- Something surprises you (a gotcha)

**Format:** Use `[category]` tags (inspired by Basic Memory's observation format):

```
- [fact] Project uses pnpm, not npm
- [preference] User prefers functional style over classes
- [convention] API routes follow /api/v1/{resource} pattern
- [gotcha] Docker build fails if .env is missing
- [decision] ADR-001: Chose PostgreSQL over MySQL — see DECISIONS.md
```

---

## Project Facts
<!-- Durable facts about this project that every session needs to know. -->
<!-- Example: -->
<!-- - [fact] This is a boilerplate for AI agent configuration -->
<!-- - [fact] Works with Claude Code, OpenCode, Codex, Cursor, Aider, etc. -->

---

## Decisions (Index)
<!-- One-line summaries pointing to DECISIONS.md for full ADRs. -->
<!-- Example: -->
<!-- - [decision] ADR-001: File-based memory over database — simplicity + portability -->

---

## Conventions (Index)
<!-- One-line summaries pointing to PATTERNS.md for full details. -->
<!-- Example: -->
<!-- - [convention] Files use kebab-case, components use PascalCase -->

---

## Gotchas (Index)
<!-- One-line summaries pointing to LESSONS.md for full details. -->
<!-- Example: -->
<!-- - [gotcha] OpenCode: limit.context MUST be set or compaction never triggers -->

---

## Preferences
<!-- User preferences, style choices, tool choices discovered during work. -->
<!-- Example: -->
<!-- - [preference] User prefers concise commit messages -->
<!-- - [preference] Always use TypeScript strict mode -->

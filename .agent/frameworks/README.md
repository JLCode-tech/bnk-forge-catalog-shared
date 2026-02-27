# Framework Compatibility

> **KEEP LEAN**: Max 40 lines.

## Native Support (reads AGENTS.md / .agent/ automatically)
| Framework | Setup |
|-----------|-------|
| Claude Code | `CLAUDE.md` at root + `.claude/` dir (rules, skills, hooks, commands) |
| OpenCode | `instructions` in `opencode.json` + `.opencode/agents/` |
| Codex CLI/App | Reads `AGENTS.md` natively |
| Goose (AAIF) | Reads `AGENTS.md` natively |

## Config-Based (copy/link instructions)
| Framework | Setup |
|-----------|-------|
| Cursor | Copy to `.cursorrules` or `.cursor/rules/` |
| Aider | Add to `.aider.conf.yml` read: |
| Copilot | Copy to `.github/copilot-instructions.md` |
| Windsurf | Point to `.agent/AGENTS.md` |

## Quick Setup
```bash
# Claude Code (full integration)
cp .agent/AGENTS.md CLAUDE.md
mkdir -p .claude/rules && cp .agent/rules/*.md .claude/rules/

# OpenCode (via opencode.json instructions)
# Add: "instructions": ["AGENTS.md", ".agent/rules/*.md"]

# Cursor
cat .agent/AGENTS.md .agent/rules/*.md > .cursorrules

# Copilot
cp .agent/AGENTS.md .github/copilot-instructions.md

# Aider - add to .aider.conf.yml:
# read: [.agent/AGENTS.md]
```

## Standards
- **AGENTS.md** = Agent Skills Specification (agentskills.io)
- **MCP** = Model Context Protocol (modelcontextprotocol.io)
- **AAIF** = Agentic AI Foundation (aaif.io)

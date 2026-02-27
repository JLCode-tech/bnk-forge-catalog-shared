# Agent Skills (Slash Commands)

> Templates for Claude Code skills (`.claude/skills/`) and equivalent commands for other agents.
> Each skill follows: When / What / Steps / Troubleshooting / Related.

## Available Skill Templates

| Skill | File | Purpose |
|-------|------|---------|
| `/status` | `status.md` | Quick project status check |
| `/validate` | `validate.md` | Run all quality checks |
| `/sprint` | `sprint.md` | Sprint progress report |

## How to Use

### Claude Code
Copy skill files to `.claude/skills/`:
```bash
cp .agent/skills/*.md .claude/skills/
```
Then invoke with `/status`, `/validate`, etc. in Claude Code.

### Other Agents
Skills are just structured checklists. Paste the content as a prompt:
```
Run the /status check from .agent/skills/status.md
```

## Creating Custom Skills

Use this template:
```markdown
# Skill: /your-command

## When to Use
[One sentence describing when this skill is useful]

## What This Skill Does
1. [Step summary]
2. [Step summary]

## Step-by-Step Instructions
[Detailed steps with actual bash commands]

## Troubleshooting
- **Problem**: [description] → **Fix**: [solution]

## Related
- [Link to related file or docs]
```

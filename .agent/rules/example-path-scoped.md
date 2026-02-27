---
# Path-Scoped Rule Example
# This rule only applies when the agent is working on files matching these paths.
# Supported by Claude Code (.claude/rules/) and used as convention by OpenCode agents.
#
# Agents: Check the `paths` frontmatter. If the file you're editing doesn't match,
# you can skip this rule.
#
# paths: ["src/api/**/*.ts", "src/api/**/*.js"]
# alwaysApply: false
---

# API Development Rules

> **Scope**: Only applies to files in `src/api/`

## Request Handling
- All handlers use try/catch with `standardErrorResponse()`
- Use Zod for request body/query validation
- Return consistent envelope: `{ data, error, meta }`

## Security
- Rate limiting on all public endpoints
- Input sanitization before DB queries
- Never expose internal errors to clients

## Testing
- Every endpoint has integration tests
- Test happy path, validation errors, auth errors, and edge cases
- Use test fixtures, not production data

---

**NOTE**: This is an EXAMPLE file. Delete or customize it for your project.
To create your own path-scoped rules:

1. Add YAML frontmatter with `paths:` glob patterns
2. The agent reads the frontmatter and decides if the rule applies
3. For Claude Code: copy to `.claude/rules/` (native path-scoping)
4. For OpenCode: loaded via `instructions: [".agent/rules/*.md"]` globs

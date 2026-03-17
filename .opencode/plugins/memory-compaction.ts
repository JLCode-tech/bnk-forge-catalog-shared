import type { Plugin } from "@opencode-ai/plugin"

/**
 * Memory Compaction Plugin
 *
 * Injects recovery instructions into the compaction summary so the agent
 * knows exactly how to resume after context is compacted. This is stronger
 * than relying on the agent to read instructions post-compaction — the
 * recovery protocol becomes part of the compaction output itself.
 */
export const MemoryCompaction: Plugin = async (ctx) => {
  return {
    "experimental.session.compacting": async (_input, output) => {
      output.context.push(`## CRITICAL: Post-Compaction Recovery Protocol

After compaction, the agent MUST follow this exact sequence:

1. **Check TodoWrite** — find the \`in_progress\` item. This is your current task.
2. **Read \`.agent/CURRENT_WORK.md\`** — your last checkpoint of progress and context.
3. **Continue the in_progress task immediately.** Your FIRST action must be a tool call (edit, write, bash, grep) that advances the work.

### What NOT to do after compaction
- DO NOT summarize what happened in previous sessions
- DO NOT output a status report or recap to the user
- DO NOT ask "What would you like me to do?" or "Should I continue?"
- DO NOT re-read every memory file before acting
- Your first response MUST be a tool call, not a text message

### Memory files in context
The following files are already loaded via the instructions array — no need to re-read:
- \`.agent/AGENTS.md\` — operating protocol
- \`.agent/CURRENT_WORK.md\` — active task state
- \`.agent/MEMORY.md\` — project knowledge
- \`.agent/LESSONS.md\` — gotchas and pitfalls
- \`.agent/PATTERNS.md\` — code conventions
- \`.agent/DECISIONS.md\` — architecture decisions

### If no TodoWrite state exists
Check \`.agent/backlog/BACKLOG.md\` for the \`current:\` item or pick the highest priority \`ready\` item.`)
    },
  }
}

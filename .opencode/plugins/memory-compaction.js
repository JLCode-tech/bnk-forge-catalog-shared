/**
 * Memory Compaction Plugin — v3 (plain JS, no Bun/TS required)
 *
 * Three layers of defense against post-compaction "helpful assistant" mode:
 *
 * 1. `experimental.chat.system.transform` — PRIMARY. Appends recovery instructions
 *    to the system prompt on EVERY message. After compaction, the agent sees these
 *    in its system prompt regardless of what the compaction summary contains.
 *
 * 2. `experimental.session.compacting` — SECONDARY. Injects recovery instructions
 *    into the compaction prompt so the summarizer LLM is told to preserve them.
 *    (Known to be unreliable — GitHub #17412 — but costs nothing to keep.)
 *
 * 3. `event` — DIAGNOSTIC. Logs compaction events so we can verify the plugin loads.
 *
 * See: https://github.com/anomalyco/opencode/issues/17412
 */

const RECOVERY_PROTOCOL = `
## CRITICAL: Post-Compaction Recovery Protocol

If context was just compacted (you notice limited conversation history):

1. **Check TodoWrite** — find the \`in_progress\` item. This is your current task.
2. **Read \`.agent/CURRENT_WORK.md\`** — your last checkpoint of progress and context.
3. **Continue the in_progress task immediately.** Your FIRST action must be a tool call (edit, write, bash, grep) that advances the work.

### What NOT to do after compaction
- DO NOT summarize what happened in previous sessions
- DO NOT output a status report or recap to the user
- DO NOT ask "What would you like me to do?" or "Should I continue?"
- DO NOT re-read every memory file before acting
- Your first response MUST be a tool call, not a text message

### If no TodoWrite state exists
Check \`.agent/backlog/BACKLOG.md\` for the \`current:\` item or pick the highest priority \`ready\` item.
`.trim()

export const MemoryCompaction = async (ctx) => {
  // Log that the plugin loaded successfully
  try {
    await ctx.client.app.log({
      body: {
        service: "memory-compaction",
        level: "info",
        message: "Memory Compaction Plugin loaded (v3 — plain JS, no Bun required)",
      },
    })
  } catch (_) {
    // client.app.log may not be available — fail silently
  }

  return {
    // Layer 1 (PRIMARY): Append recovery instructions to the system prompt
    // This runs on EVERY LLM call — the agent always sees it
    "experimental.chat.system.transform": async (_input, output) => {
      const alreadyPresent = output.system.some(
        (s) => s.includes("Post-Compaction Recovery Protocol")
      )
      if (!alreadyPresent) {
        output.system.push(RECOVERY_PROTOCOL)
      }
    },

    // Layer 2 (SECONDARY): Inject into the compaction prompt
    // The compaction LLM sees this and should include it in the summary
    "experimental.session.compacting": async (_input, output) => {
      output.context.push(RECOVERY_PROTOCOL)

      try {
        await ctx.client.app.log({
          body: {
            service: "memory-compaction",
            level: "info",
            message: `Compaction hook fired for session ${_input.sessionID} — recovery protocol injected`,
          },
        })
      } catch (_) {
        // fail silently
      }
    },

    // Layer 3 (DIAGNOSTIC): Log compaction events
    event: async ({ event }) => {
      if (event.type === "session.compacted") {
        try {
          await ctx.client.app.log({
            body: {
              service: "memory-compaction",
              level: "warn",
              message: "Session compacted — recovery protocol active via system.transform hook",
            },
          })
        } catch (_) {
          // fail silently
        }
      }
    },
  }
}

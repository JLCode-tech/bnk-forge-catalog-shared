---
description: Resume work after compaction or new session — reads state and continues
agent: stateful
---

IMMEDIATELY resume working. Your first action must be a tool call, not text.

1. Check TodoWrite — find the `in_progress` item.
2. Read `.agent/CURRENT_WORK.md` — your last checkpoint of progress.
3. Continue the `in_progress` task. Your next tool call should be an edit, write, bash, or grep — whatever the task requires.

If no `in_progress` item exists in TodoWrite, check `.agent/backlog/BACKLOG.md` and pick the highest priority `ready` item.

DO NOT summarize. DO NOT recap. DO NOT ask what to do. Just continue.

---
name: sprint
description: Track multi-session sprint progress — read tracker, update completion, report status
---

## What This Does

Check and update progress for a multi-session sprint (test coverage push, feature build, migration, etc.).

## Steps

### 1. Find Active Sprint
```bash
ls .agent/progress/*.md 2>/dev/null | grep -v README
```

### 2. Read Sprint Tracker
Parse the active sprint file for:
- Total items vs completed items
- Current phase/wave
- Blockers

### 3. Report Progress
```
Progress: [completed]/[total] items ([percentage]%)
Phase: [current phase] of [total phases]
Blockers: [list or "none"]
```

### 4. Update After Work
After completing items this session:
1. Mark completed items in the tracker
2. Update the completion count
3. Note any new blockers or discoveries
4. Update `CURRENT_WORK.md` with sprint status

### 5. Sprint Completion
When all items done:
1. Move sprint tracker to `archive/sprints/`
2. Update `CURRENT_WORK.md`
3. Clear sprint items from `BACKLOG.md`, promote next sprint

## Sprint Tracker Template

```markdown
# Sprint: [NAME]
**Goal:** [one sentence]
**Started:** YYYY-MM-DD | **Target:** YYYY-MM-DD
**Progress:** 0/N items (0%)

## Phases
### Phase 1: [Name]
- [ ] Item 1
- [ ] Item 2

## Blockers
- None

## Metrics
| Metric | Baseline | Current | Target |
|--------|----------|---------|--------|
| [metric] | [value] | [value] | [value] |
```

## Notes
- If no sprint file exists, create one in `progress/` using the template above.
- If sprint is stalled, check blockers and consider splitting large items.

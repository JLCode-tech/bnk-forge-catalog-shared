# Skill: /sprint

## When to Use
When running a multi-session sprint (test coverage, feature build, migration, etc.)
to check progress and update tracking.

## What This Skill Does
1. Reads the active sprint tracker from `progress/`
2. Calculates completion percentage
3. Shows remaining items
4. Updates progress file with current session's work

## Step-by-Step Instructions

### 1. Find Active Sprint
```bash
ls .agent/progress/*.md 2>/dev/null | grep -v README
```

### 2. Read Sprint Tracker
Read the active sprint file and parse:
- Total items vs completed items
- Current phase/wave
- Blockers

### 3. Calculate Progress
```
Progress: [completed]/[total] items ([percentage]%)
Phase: [current phase] of [total phases]
Blockers: [list or "none"]
```

### 4. Update Sprint Tracker
After completing work in this session:
1. Mark completed items in the tracker
2. Update the completion count
3. Note any new blockers or discoveries
4. Update CURRENT_WORK.md with sprint status

### 5. Sprint Completion
When all items are done:
1. Move sprint tracker to `archive/sprints/`
2. Update CURRENT_WORK.md
3. Update BACKLOG.md (clear sprint items, promote next sprint)

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

### Phase 2: [Name]
- [ ] Item 3
- [ ] Item 4

## What NOT to Do
- [Anti-pattern 1]
- [Anti-pattern 2]

## Blockers
- None

## Metrics
| Metric | Baseline | Current | Target |
|--------|----------|---------|--------|
| [metric] | [value] | [value] | [value] |
```

## Troubleshooting
- **No sprint file**: Create one in `progress/` using the template above
- **Sprint stalled**: Check blockers, re-prioritize, or split large items

## Related
- `.agent/progress/` — sprint tracker directory
- `.agent/backlog/BACKLOG.md` — work queue
- `.agent/rules/archive-policy.md` — when to archive completed sprints

# Progress & Sprint Tracking

> **KEEP LEAN**: Delete old entries. Max 1 week of daily logs.
> Completed sprints move to `archive/sprints/`.

## Daily Logs
Files: `YYYY-MM-DD.md`

```markdown
## HH:MM - [Start/End/Handoff]
**Item:** [id] | **Branch:** [branch]
- Accomplished X
- Note: Y
```

## Sprint Trackers
For multi-session work (test coverage, migrations, feature sprints):

```markdown
# Sprint: [NAME]

**Goal:** [one sentence]
**Started:** YYYY-MM-DD | **Target:** YYYY-MM-DD
**Progress:** 0/N items (0%)

## Phases
### Phase 1: [Name]
- [ ] Item 1
- [ ] Item 2

## What NOT to Do
- [Anti-pattern derived from experience]

## Blockers
- None

## Metrics
| Metric | Baseline | Current | Target |
|--------|----------|---------|--------|
```

## Sprint Lifecycle
1. Create tracker in `progress/SPRINT_NAME.md`
2. Set `sprints.active` in `config.yaml`
3. Update progress each session
4. When complete: move to `archive/sprints/`, clear `sprints.active`

---
name: validate
description: Run all quality gates before committing — lint, types, tests, build
---

## What This Does

Full pre-commit quality gate. Run this before committing or creating a PR.

## Steps

### 1. Install Dependencies
```bash
npm install 2>/dev/null || pip install -r requirements.txt 2>/dev/null || true
```

### 2. Lint
```bash
npm run lint 2>&1
```
If auto-fixable issues, run `npm run lint -- --fix` then re-check.

### 3. Type Check (TypeScript projects)
```bash
npx tsc --noEmit 2>&1 || echo "No TypeScript config"
```

### 4. Tests
```bash
npm test 2>&1
```

### 5. Build
```bash
npm run build 2>&1
```

### 6. Report
```
Validation Results:
  Lint:       PASS/FAIL (N issues)
  Types:      PASS/FAIL/SKIP
  Tests:      PASS/FAIL (N passed, N failed)
  Build:      PASS/FAIL
```

If any step fails, report the first error clearly and stop.

## Notes
- Fix lint formatting issues first (`npm run format`), then re-lint.
- If tests timeout, check if DB/services need starting (`docker-compose up`).
- Fix type errors before other issues — they cascade.

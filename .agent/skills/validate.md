# Skill: /validate

## When to Use
Before committing, before creating a PR, or when you want to verify everything is clean.

## What This Skill Does
1. Runs linter
2. Runs type checker (if applicable)
3. Runs test suite
4. Runs build
5. Reports pass/fail summary

## Step-by-Step Instructions

### 1. Install Dependencies (if needed)
```bash
npm install 2>/dev/null || pip install -r requirements.txt 2>/dev/null || true
```

### 2. Lint
```bash
npm run lint 2>&1
# Note: fix any auto-fixable issues with `npm run lint -- --fix`
```

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
Create a summary:
```
Validation Results:
  Lint:       PASS/FAIL (N issues)
  Types:      PASS/FAIL/SKIP
  Tests:      PASS/FAIL (N passed, N failed)
  Build:      PASS/FAIL
```

If any step fails, report the first error clearly.

## Troubleshooting
- **Lint fails on formatting**: Run `npm run format` first, then re-lint
- **Tests timeout**: Check if DB/services are running (docker-compose up)
- **Build fails on types**: Fix type errors before other issues

## Related
- `.agent/rules/code-quality.md` — quality standards
- `.agent/config.yaml` — project commands

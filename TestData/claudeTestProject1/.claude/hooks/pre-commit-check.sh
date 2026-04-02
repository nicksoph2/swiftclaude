#!/usr/bin/env bash
# .claude/hooks/pre-commit-check.sh
# PreToolUse hook for git commit — runs typecheck and lint before allowing the commit.

set -euo pipefail

cd "$CLAUDE_PROJECT_DIR"

echo "Running pre-commit checks..."

npm run typecheck 2>&1 || {
  echo "ERROR: TypeScript type errors found. Fix them before committing." >&2
  exit 2
}

npm run lint 2>&1 || {
  echo "ERROR: ESLint errors found. Run 'npm run lint:fix' or fix manually." >&2
  exit 2
}

echo "Pre-commit checks passed."
exit 0

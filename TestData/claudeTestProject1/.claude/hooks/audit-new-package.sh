#!/usr/bin/env bash
# .claude/hooks/audit-new-package.sh
# PostToolUse hook for npm install — runs npm audit on newly installed packages.

set -uo pipefail

cd "$CLAUDE_PROJECT_DIR"

AUDIT_OUTPUT=$(npm audit --audit-level=high --json 2>/dev/null || true)
VULNS=$(echo "$AUDIT_OUTPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('metadata',{}).get('vulnerabilities',{}).get('high',0)+d.get('metadata',{}).get('vulnerabilities',{}).get('critical',0))" 2>/dev/null || echo "0")

if [ "$VULNS" -gt 0 ]; then
  echo "⚠ npm audit found $VULNS high/critical vulnerabilities. Run 'npm audit' for details." >&2
fi

exit 0

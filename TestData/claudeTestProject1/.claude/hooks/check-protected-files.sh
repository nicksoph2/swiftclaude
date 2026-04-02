#!/usr/bin/env bash
# .claude/hooks/check-protected-files.sh
# PreToolUse hook for Edit|Write — blocks writes to protected paths.

set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('file_path',''))" 2>/dev/null || true)

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Normalise to relative path from project root
REL="${FILE_PATH#${CLAUDE_PROJECT_DIR}/}"

PROTECTED=(
  ".env"
  ".env.production"
  ".env.staging"
  "secrets/"
  "prisma/migrations/"
)

for pattern in "${PROTECTED[@]}"; do
  if [[ "$REL" == "$pattern"* ]]; then
    echo "BLOCKED: $REL is a protected path. Use the appropriate workflow to modify this file." >&2
    # Output the hook decision JSON
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Protected file path"}}'
    exit 2
  fi
done

exit 0

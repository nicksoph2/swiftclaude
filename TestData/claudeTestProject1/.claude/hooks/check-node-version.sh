#!/usr/bin/env bash
# .claude/hooks/check-node-version.sh
# PreToolUse hook for Bash(npm *) — ensures the correct Node.js version is active.

set -euo pipefail

REQUIRED=$(cat "${CLAUDE_PROJECT_DIR}/.nvmrc" 2>/dev/null || echo "20")
CURRENT=$(node --version 2>/dev/null | sed 's/v//' | cut -d. -f1)

if [ "$CURRENT" != "$REQUIRED" ]; then
  echo "ERROR: Node.js $REQUIRED required (currently $CURRENT). Run: nvm use" >&2
  # Exit code 2 blocks the tool call
  exit 2
fi

exit 0

#!/usr/bin/env bash
# .claude/hooks/log-failure.sh
# PostToolUseFailure hook (async) — logs failed Bash commands.

LOG="$CLAUDE_PROJECT_DIR/.claude/hooks/failures.log"
mkdir -p "$(dirname "$LOG")"

INPUT=$(cat)
TS=$(date -u +%FT%TZ)
echo "${TS}	${INPUT}" >> "$LOG"
exit 0

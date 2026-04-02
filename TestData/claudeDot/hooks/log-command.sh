#!/usr/bin/env bash
# ~/.claude/hooks/log-command.sh
# PreToolUse hook (async) — appends a line to the session command log.
# Runs in the background so it never blocks Claude.

LOG="$HOME/.claude/hooks/commands.log"
mkdir -p "$(dirname "$LOG")"

# Claude passes the tool input as JSON on stdin for PreToolUse hooks
INPUT=$(cat)
TOOL="${CLAUDE_TOOL_NAME:-unknown}"
PROJECT="${CLAUDE_PROJECT_DIR:-unknown}"
TS=$(date -u +%FT%TZ)

echo "${TS}	${PROJECT}	${TOOL}	${INPUT}" >> "$LOG"

exit 0

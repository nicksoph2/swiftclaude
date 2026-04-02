#!/usr/bin/env bash
# .claude/hooks/session-cleanup.sh
# Stop hook (async) — logs session end time.

LOG="$CLAUDE_PROJECT_DIR/.claude/hooks/session.log"
echo "[$(date -u +%FT%TZ)] SessionEnd" >> "$LOG"
exit 0

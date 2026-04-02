#!/usr/bin/env bash
# .claude/hooks/save-context-snapshot.sh
# PreCompact hook — saves a snapshot of key project state before context is compacted.

set -uo pipefail

SNAPSHOT_DIR="$CLAUDE_PROJECT_DIR/.claude/plans"
mkdir -p "$SNAPSHOT_DIR"
SNAPSHOT="$SNAPSHOT_DIR/pre-compact-$(date -u +%Y%m%dT%H%M%S).md"

{
  echo "# Context snapshot — $(date -u +%FT%TZ)"
  echo ""
  echo "## Git status"
  git -C "$CLAUDE_PROJECT_DIR" status --short 2>/dev/null || echo "(not a git repo)"
  echo ""
  echo "## Recent commits"
  git -C "$CLAUDE_PROJECT_DIR" log --oneline -10 2>/dev/null || echo "(no commits)"
  echo ""
  echo "## Modified files"
  git -C "$CLAUDE_PROJECT_DIR" diff --name-only 2>/dev/null || echo "(none)"
} > "$SNAPSHOT"

echo "Context snapshot saved to $SNAPSHOT" >&2
exit 0

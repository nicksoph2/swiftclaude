#!/usr/bin/env bash
# .claude/hooks/session-init.sh
# SessionStart hook — checks local services are running and exports context.

set -euo pipefail

LOG="$CLAUDE_PROJECT_DIR/.claude/hooks/session.log"
echo "[$(date -u +%FT%TZ)] SessionStart" >> "$LOG"

# Check PostgreSQL is reachable
if command -v pg_isready &>/dev/null; then
  if pg_isready -h localhost -p 5432 -q 2>/dev/null; then
    echo "✓ PostgreSQL reachable" >&2
  else
    echo "⚠ PostgreSQL not reachable on :5432 — integration tests will fail" >&2
  fi
fi

# Check Redis is reachable
if command -v redis-cli &>/dev/null; then
  if redis-cli -p 6379 ping &>/dev/null; then
    echo "✓ Redis reachable" >&2
  else
    echo "⚠ Redis not reachable on :6379 — cache and job queue features will fail" >&2
  fi
fi

# Inject project context into the session
cat >> "${CLAUDE_ENV_FILE:-/dev/null}" <<'EOF'
ACME_API_PROJECT=true
EOF

# Pass additional context to Claude via hookSpecificOutput
echo '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"acme-api project. Fastify + Prisma + BullMQ stack. Run '\''npm run dev'\'' to start the server. See CLAUDE.md for full context."}}'

exit 0

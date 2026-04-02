#!/usr/bin/env bash
# ~/.claude/hooks/load-env.sh
# SessionStart hook — loads user environment variables into the Claude session.
# Writes exports to $CLAUDE_ENV_FILE so they persist for the session.

set -euo pipefail

LOG="$HOME/.claude/hooks/session.log"
echo "[$(date -u +%FT%TZ)] SessionStart in ${CLAUDE_PROJECT_DIR:-unknown}" >> "$LOG"

# Load nvm if present
if [ -s "$HOME/.nvm/nvm.sh" ]; then
  source "$HOME/.nvm/nvm.sh" --no-use
  # Use the project's .nvmrc if one exists
  if [ -f "${CLAUDE_PROJECT_DIR:-}/.nvmrc" ]; then
    NVM_VER=$(cat "${CLAUDE_PROJECT_DIR}/.nvmrc")
    echo "NVM_VERSION=$NVM_VER" >> "${CLAUDE_ENV_FILE:-/dev/null}"
    echo "[load-env] Using Node $NVM_VER from .nvmrc" >> "$LOG"
  fi
fi

# Export any project-local .env.claude if present (non-secret convenience vars only)
ENV_CLAUDE="${CLAUDE_PROJECT_DIR:-}/.env.claude"
if [ -f "$ENV_CLAUDE" ]; then
  while IFS='=' read -r key val; do
    [[ "$key" =~ ^#.*$ ]] && continue
    [[ -z "$key" ]] && continue
    echo "${key}=${val}" >> "${CLAUDE_ENV_FILE:-/dev/null}"
  done < "$ENV_CLAUDE"
  echo "[load-env] Loaded .env.claude" >> "$LOG"
fi

exit 0

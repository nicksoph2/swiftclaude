#!/usr/bin/env bash
# .claude/hooks/post-edit-lint.sh
# PostToolUse hook for Edit|Write — lints the changed file immediately.

set -uo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('file_path',''))" 2>/dev/null || true)

if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

EXT="${FILE_PATH##*.}"

case "$EXT" in
  ts|tsx)
    cd "$CLAUDE_PROJECT_DIR"
    npx eslint "$FILE_PATH" --max-warnings=0 --no-eslintrc --config .eslintrc.json 2>&1 || true
    ;;
  js|jsx|mjs)
    cd "$CLAUDE_PROJECT_DIR"
    npx eslint "$FILE_PATH" --max-warnings=0 2>&1 || true
    ;;
  *)
    ;;
esac

# Always exit 0 from PostToolUse — don't block on lint warnings
exit 0

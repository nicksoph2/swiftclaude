#!/usr/bin/env bash
# ~/.claude/hooks/auto-format.sh
# PostToolUse hook for Edit|Write — runs the appropriate formatter on the changed file.

set -euo pipefail

# Claude passes PostToolUse input as JSON on stdin
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('file_path',''))" 2>/dev/null || true)

if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

EXT="${FILE_PATH##*.}"

case "$EXT" in
  ts|tsx|js|jsx|mjs|cjs)
    if command -v prettier &>/dev/null; then
      prettier --write "$FILE_PATH" --log-level warn
    fi
    ;;
  py)
    if command -v black &>/dev/null; then
      black "$FILE_PATH" -q
    fi
    ;;
  go)
    if command -v gofmt &>/dev/null; then
      gofmt -w "$FILE_PATH"
    fi
    ;;
  json)
    if command -v jq &>/dev/null; then
      TMP=$(mktemp)
      jq . "$FILE_PATH" > "$TMP" && mv "$TMP" "$FILE_PATH"
    fi
    ;;
  *)
    # No formatter for this type — exit cleanly
    ;;
esac

exit 0

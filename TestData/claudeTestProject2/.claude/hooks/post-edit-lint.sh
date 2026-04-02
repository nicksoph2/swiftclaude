#!/usr/bin/env bash
# .claude/hooks/post-edit-lint.sh
# PostToolUse hook for Edit|Write — runs ESLint and Prettier check on changed file.

set -uo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('file_path',''))" 2>/dev/null || true)

if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

EXT="${FILE_PATH##*.}"
cd "$CLAUDE_PROJECT_DIR"

case "$EXT" in
  ts|tsx|js|jsx)
    npx eslint "$FILE_PATH" --max-warnings=0 2>&1 || true
    npx prettier --check "$FILE_PATH" 2>&1 || true
    ;;
  mdx|md)
    # Basic frontmatter check for blog posts
    if [[ "$FILE_PATH" == *"/content/posts/"* ]]; then
      if ! grep -q "^published:" "$FILE_PATH"; then
        echo "WARNING: Missing 'published:' field in frontmatter" >&2
      fi
    fi
    ;;
esac

exit 0

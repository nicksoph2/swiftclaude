#!/usr/bin/env bash
# .claude/hooks/check-content-paths.sh
# PreToolUse hook for Edit|Write — validates MDX post filenames follow the convention.

set -uo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('file_path',''))" 2>/dev/null || true)

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Only check files in content/posts/
if [[ "$FILE_PATH" != *"/content/posts/"* ]]; then
  exit 0
fi

BASENAME=$(basename "$FILE_PATH")

# MDX posts must be named YYYY-MM-DD-slug.mdx
if [[ "$BASENAME" =~ \.mdx$ ]] && ! [[ "$BASENAME" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-.+\.mdx$ ]]; then
  echo "WARNING: Post filename '$BASENAME' doesn't follow YYYY-MM-DD-slug.mdx convention" >&2
fi

exit 0

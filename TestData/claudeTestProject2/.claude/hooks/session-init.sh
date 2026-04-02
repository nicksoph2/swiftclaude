#!/usr/bin/env bash
# .claude/hooks/session-init.sh
# SessionStart hook — provides project context.

echo '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"personal-site: Next.js 14 App Router + Tailwind + MDX blog. Blog posts are in content/posts/ as YYYY-MM-DD-slug.mdx. Use '\''npm run dev'\'' to start on port 3000."}}'
exit 0

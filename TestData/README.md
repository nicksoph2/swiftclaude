# Claude Code Admin App — Test Data

Three folders that replicate a real Claude Code filesystem layout.
All config formats are sourced directly from https://code.claude.com/docs.

---

## claudeDot  →  mimics  ~/.claude/  (plus ~/.claude.json)

| File | Real path | What it is |
|---|---|---|
| `settings.json` | `~/.claude/settings.json` | User-level settings: model, permissions, hooks, env |
| `claude.json` | `~/.claude.json` | Global config: MCP servers, per-project state, editor mode |
| `CLAUDE.md` | `~/.claude/CLAUDE.md` | User-level instructions (applies to every project) |
| `agents/code-reviewer.md` | `~/.claude/agents/code-reviewer.md` | User-level subagent — available in all projects |
| `agents/request-screener.md` | `~/.claude/agents/request-screener.md` | Security-screening subagent used by UserPromptSubmit hook |
| `hooks/load-env.sh` | `~/.claude/hooks/load-env.sh` | SessionStart hook script |
| `hooks/log-command.sh` | `~/.claude/hooks/log-command.sh` | Async PreToolUse logging script |
| `hooks/auto-format.sh` | `~/.claude/hooks/auto-format.sh` | PostToolUse formatter script |
| `plans/` | `~/.claude/plans/` | Where Claude saves plan files (empty at start) |

**Key things to test from this folder:**
- `claude.json` contains `mcpServers` (user-level) and `projects` state (per-project `allowedTools`, `hasTrustDialogAccepted`) — these are global-config-only keys that are invalid in `settings.json`
- `settings.json` has a mix of hook types: `command` (PreToolUse), `command` (PostToolUse), `prompt` (Stop), `command` (SessionStart), `command` (FileChanged)
- Agent frontmatter fields: `name`, `description`, `tools`, `model`, `color`, `memory`, `maxTurns`

---

## claudeTestProject1  →  mimics  ~/Projects/acme-api/

A TypeScript/Fastify backend API project with enterprise-style hooks and a custom subagent.

| File | Real path | What it is |
|---|---|---|
| `CLAUDE.md` | `<project>/CLAUDE.md` | Project instructions with `@include` directives |
| `.mcp.json` | `<project>/.mcp.json` | Project MCP servers (stdio + SSE transports) |
| `.claude/settings.json` | `<project>/.claude/settings.json` | Shared team settings (committed to git) |
| `.claude/settings.local.json` | `<project>/.claude/settings.local.json` | Personal local overrides (gitignored) |
| `.claude/agents/db-migration-helper.md` | `<project>/.claude/agents/db-migration-helper.md` | Project-scoped subagent |
| `.claude/hooks/*.sh` | `<project>/.claude/hooks/` | Hook scripts referenced in settings.json |
| `.claude/instructions/*.md` | `<project>/.claude/instructions/` | Files referenced via `@` in CLAUDE.md |
| `.claude/plans/` | `<project>/.claude/plans/` | Plan files directory |

**Key things to test from this folder:**
- `settings.json` covers every major hook event: `PreToolUse` (with `matcher`), `PostToolUse` (command + http), `PostToolUseFailure`, `SessionStart`, `Stop`, `PreCompact`, `UserPromptSubmit` (agent hook type)
- HTTP hook on PostToolUse with `allowedEnvVars`, `async: true`, custom headers
- Agent hook type on `UserPromptSubmit` — inline prompt, haiku model, `once: true`
- `settings.local.json` uses `defaultMode: "bypassPermissions"` with `skipDangerousModePermissionPrompt: true` and overrides model/effort
- `.mcp.json` has both `stdio` (npm packages) and `sse` (internal URL with auth header) transports
- `check-protected-files.sh` emits `hookSpecificOutput` JSON with `permissionDecision: "deny"`
- `session-init.sh` emits `hookSpecificOutput` JSON with `additionalContext`

---

## claudeTestProject2  →  mimics  ~/Projects/personal-site/

A personal Next.js blog — lighter config, different hook concerns.

| File | Real path | What it is |
|---|---|---|
| `CLAUDE.md` | `<project>/CLAUDE.md` | Project instructions |
| `.mcp.json` | `<project>/.mcp.json` | Two MCP servers (github + fetch) |
| `.claude/settings.json` | `<project>/.claude/settings.json` | Project settings — simpler, no HTTP hooks |
| `.claude/settings.local.json` | `<project>/.claude/settings.local.json` | Minimal local overrides |
| `.claude/agents/content-reviewer.md` | `<project>/.claude/agents/content-reviewer.md` | Blog content review subagent |
| `.claude/hooks/*.sh` | `<project>/.claude/hooks/` | Content-path validation + lint hooks |
| `.claude/plans/` | `<project>/.claude/plans/` | Plan files directory |

**Key things to test from this folder:**
- Simpler permissions set compared to project 1 — good contrast case
- `content-reviewer` agent has no `hooks`, `mcpServers`, or `permissionMode` (deliberately minimal)
- `check-content-paths.sh` validates MDX filename convention, emits only a warning (exit 0)
- `settings.local.json` is intentionally minimal — just model + one extra allow rule

---

## Scope resolution summary

When the app resolves settings for a session in claudeTestProject1, the precedence (high→low) is:

1. **Managed** — not present in this test data; your app should handle absence gracefully
2. **Local** — `.claude/settings.local.json` (e.g. `model: claude-opus-4-6`, `defaultMode: bypassPermissions`)
3. **Project** — `.claude/settings.json` (e.g. `model: claude-sonnet-4-6`, `defaultMode: acceptEdits`)
4. **User** — `claudeDot/settings.json` (e.g. `model: claude-sonnet-4-6`, `cleanupPeriodDays: 30`)

Winner for `model` → Local (`claude-opus-4-6`)
Winner for `defaultMode` → Local (`bypassPermissions`)
Winner for `cleanupPeriodDays` → Project (7), overrides User (30)
Winner for MCP servers → union of `.mcp.json` + `claude.json` mcpServers, filtered by `enabledMcpjsonServers`

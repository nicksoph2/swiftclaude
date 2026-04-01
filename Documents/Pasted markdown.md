Claude Config Manager

1. Executive summary

Claude Config Manager is a native macOS application for inspecting, validating, and editing the real configuration surface used by Claude Code. The app is not a second source of truth. It reads Claude’s live files on demand, resolves the currently effective state in memory, and writes changes back atomically to Claude-owned files or to a small number of app-owned reproducible files.

The application provides four scope views:

Managed
User
Project
Session (resolved, read-only)

It also provides five functional areas:

Settings
Memory / Instructions
Hooks
Agents / Skills / Commands
Usage / Telemetry

This version is aligned to Claude Code’s current documented configuration model, including:

settings.json hierarchy,
CLAUDE.md hierarchy,
.mcp.json,
~/.claude.json global preferences and user/local MCP storage,
agent files in .claude/agents/,
skill files in .claude/skills/,
and hook configuration in settings files. 2. Design principles
Claude files are authoritative.
The app always reads Claude’s current files at open, refresh, and before save.
No shadow database.
The app does not maintain a secondary relational store of configuration, instructions, hooks, or usage.
Reproducible app state only.
App-owned files contain only derived, reproducible state, UI metadata, and optional locally generated usage summaries.
Write-through editing.
User edits are applied to Claude files directly using atomic swap writes.
Resolved views are computed, not persisted.
The Session view is an in-memory projection.
Native-first implementation.
The app is built in SwiftUI with targeted AppKit integration where needed. 3. Actual Claude configuration model
3.1 Scope and precedence

Claude Code’s actual documented precedence is:

Managed
Command-line arguments
Local project settings: .claude/settings.local.json
Project settings: .claude/settings.json
User settings: ~/.claude/settings.json

That is the baseline precedence the resolver must implement for settings.json-based configuration. Managed settings can also be delivered via server-managed settings, MDM/OS policy, or file-based managed settings.

3.2 Files that matter

The app must model these file classes explicitly.

Settings

~/.claude/settings.json
<project>/.claude/settings.json
<project>/.claude/settings.local.json
managed settings sources
~/.claude.json for global config and user/local MCP state, preferences, per-project trust state, and caches
<project>/.mcp.json for project-scoped MCP servers

Memory / instruction files

~/.claude/CLAUDE.md
<project>/CLAUDE.md
<project>/.claude/CLAUDE.md
managed CLAUDE.md
imported files referenced with @path/to/file from CLAUDE.md files, with recursive import depth up to 5

Auto memory

~/.claude/projects/<project>/memory/MEMORY.md
topic files in that same memory directory
Auto memory is machine-local and separate from CLAUDE.md. Claude loads the first 200 lines or 25KB of MEMORY.md at session start.

Hooks

hooks embedded in settings files at user, project, local, and managed scopes
hooks bundled by plugins
hooks defined in skill or agent frontmatter while those components are active

Agents

~/.claude/agents/_.md
<project>/.claude/agents/_.md

Skills / slash-command-related content

.claude/skills/\*_/SKILL.md
.claude/commands/_.md remains compatible, but skills are the recommended model 4. Information architecture
4.1 Managed

Read-only by default unless the selected managed delivery mechanism is file-based and writable by the user’s environment.

Subsections:

Settings
Memory / Instructions
Hooks
MCP
Policy restrictions
4.2 User

User-wide Claude state.

Subsections:

settings.json
CLAUDE.md
Auto memory root
User agents
User skills
User/local MCP from ~/.claude.json
Usage summary
4.3 Project

Project-specific Claude state for the selected repo/root.

Subsections:

Shared settings: .claude/settings.json
Local settings: .claude/settings.local.json
Project instructions: CLAUDE.md and .claude/CLAUDE.md
Project agents
Project skills
Project MCP: .mcp.json
Usage summary
App reproducible project file
4.4 Session

Read-only effective state.

Subsections:

Resolved settings
Resolved instructions in load order
Resolved hook set
Resolved MCP server set
Active agents/skills visible from this scope mix
Effective usage data sources and confidence 5. Resolver model

The resolver must be a first-class core service, not a UI concern.

5.1 Settings resolution

For each key, the Session resolver must produce:

effectiveValue
winningSource
allParticipatingSources
mergeMethod
validationIssues
notes

Merge semantics must follow Claude’s documented model where more specific settings override broader settings, while some collections merge rather than replace. Managed settings drop-ins are documented to deep-merge objects and concatenate/de-duplicate arrays in file merge order, so the resolver must support per-key merge behavior rather than a single generic overwrite rule.

5.2 Instruction resolution

Instruction load order must distinguish:

managed CLAUDE.md
user CLAUDE.md
project CLAUDE.md / .claude/CLAUDE.md
imported files via @path
auto memory index MEMORY.md
on-demand memory topic files not loaded at startup

The app must present both:

startup-loaded instruction set
available but on-demand memory files
5.3 MCP resolution

MCP precedence must model:

local-scoped MCP in ~/.claude.json
project-scoped MCP in .mcp.json
user-scoped MCP in ~/.claude.json
managed MCP

When the same server name exists at multiple scopes, local overrides project, and project overrides user. .mcp.json supports environment variable expansion in command, args, env, url, and headers.

6. Actual file schemas to support
   6.1 settings.json

The app must support these documented top-level keys at minimum:

$schema
apiKeyHelper
autoMemoryDirectory
cleanupPeriodDays
companyAnnouncements
env
attribution
includeCoAuthoredBy (deprecated)
includeGitInstructions
permissions
autoMode
disableAutoMode
useAutoModeDuringPlan
disableDeepLinkRegistration
hooks
allowManagedHooksOnly
allowedHttpHookUrls
httpHookAllowedEnvVars
plugin-related settings such as enabledPlugins, extraKnownMarketplaces, and strictKnownMarketplaces

The app must also clearly separate keys that belong in ~/.claude.json rather than settings.json, such as:

autoConnectIde
autoInstallIdeExtension
editorMode
showTurnDuration
6.1.1 Permissions object

Represent:

permissions.allow: [String]
permissions.deny: [String]

Examples include:

Bash(npm run lint)
Read(~/.zshrc)
Read(./.env)
Read(./secrets/\*\*)

UI recommendation:

rule list editor,
syntax-aware badges for tool type,
effective precedence view,
warning when a broader allow is blocked by a more specific deny.
6.1.2 Env object

Represent as string map:

env: { [String: String] }

This is the correct place for Claude session environment variables such as telemetry exporter variables shown in Anthropic’s example.

6.1.3 Attribution object

Represent as:

attribution.commit: String?
attribution.pr: String?
6.1.4 Hooks object

Model as:

{
"hooks": {
"EventName": [
{
"matcher": "regex-or-\*",
"hooks": [
{
"type": "command|http|prompt|agent",
"... event-specific fields ..."
}
]
}
]
}
}

This nested matcher-plus-hook-list shape is the documented structure.

6.2 Hook details
6.2.1 Supported events

The app must support, validate, and display at minimum the documented lifecycle events including:

SessionStart
InstructionsLoaded
UserPromptSubmit
PreToolUse
PermissionRequest
PostToolUse
PostToolUseFailure
Notification
SessionEnd
SubagentStart
SubagentStop
PreCompact
PostCompact
ConfigChange
CwdChanged
6.2.2 Matcher semantics

The matcher field is a regex string. "\*", "", or omitted means match-all. Match target depends on event type, for example tool name for PreToolUse and PostToolUse, startup mode for SessionStart, and agent type for subagent events.

6.2.3 Common hook input fields

The app must document and display common runtime input fields:

session_id
transcript_path
cwd

It should also present event-specific payloads when known.

6.2.4 Hook safety restrictions

The app must surface:

allowManagedHooksOnly
allowedHttpHookUrls
httpHookAllowedEnvVars
and explain effective restrictions after merge.
6.3 CLAUDE.md

The app must treat CLAUDE.md files as plain Markdown instruction files, not YAML-config files. It must support:

root project file at ./CLAUDE.md
alternate project file at ./.claude/CLAUDE.md
user file at ~/.claude/CLAUDE.md
managed file in system location
@path/to/file imports, with relative paths resolved from the containing file
recursive imports to max depth 5

UI recommendation:

exact load-order view,
import graph,
duplicate content warnings,
broken import warnings,
cycle/error diagnostics.
6.4 Auto memory

The app must distinguish user-authored instructions from Claude-authored auto memory.

Represent:

MEMORY.md index file
topic files in ~/.claude/projects/<project>/memory/

Rules:

app may view and validate,
app should not represent auto memory as team-shared project configuration,
app should show that only the beginning of MEMORY.md is loaded at startup,
app should label topic files as on-demand memory, not startup instructions.
6.5 Agents

Each agent file is Markdown with YAML frontmatter followed by prompt body.

Supported frontmatter:

name (required in practice)
description
tools
optionally mcpServers for inline subagent-specific server definitions, where applicable in current docs/examples

The app must validate:

lowercase/hyphen name convention,
duplicate agent names,
project-over-user precedence,
tool syntax,
Agent(agent_type) allowlist syntax where used.
6.6 Skills

Each skill is a directory with SKILL.md and optional supporting files.

Supported frontmatter fields include:

name
description
argument-hint
disable-model-invocation
user-invocable
allowed-tools
model
effort
context
agent

The app must validate:

directory naming,
frontmatter correctness,
supported tool restriction syntax,
whether a forked context requires an agent.
6.7 .mcp.json

Represent as:

{
"mcpServers": {
"server-name": {
"type": "stdio|http|sse",
"command": "...",
"args": [],
"env": {},
"url": "...",
"headers": {}
}
}
}

The app must support:

project-scoped .mcp.json,
environment variable expansion,
duplicate server-name conflict view across scopes,
approval reminder for project-scoped servers. 7. App-owned files

This app may create only these reproducible files.

7.1 Global app file

Store at:

~/Library/Containers/<bundle-id>/Data/Library/Application Support/ClaudeConfigManager/global-state.json

Purpose:

project registry
security-scoped bookmark metadata
UI preferences
global derived usage summaries
last-scan hashes
no authoritative Claude config data

This file is allowed because it is app infrastructure, not a second config database.

Suggested structure:

{
"version": 1,
"projects": [
{
"projectId": "stable-id",
"displayName": "repo-name",
"bookmarkRef": "opaque",
"lastOpenedAt": "ISO-8601"
}
],
"ui": {
"recentProjectId": "stable-id",
"sidebarState": {}
},
"usageSummary": {
"sourceMode": "derived",
"projects": {}
}
}
7.2 Per-project app file

Store at:

<project>/.claude/claude-config-manager.json

Purpose:

reproducible derived usage summary,
project-local app preferences that should travel with the repo if desired,
non-authoritative cached fingerprints for faster diffing,
explicit provenance for any app-generated token summaries.

Suggested structure:

{
"version": 1,
"derivedFrom": {
"settingsFiles": [],
"instructionFiles": [],
"mcpFiles": [],
"generatedAt": "ISO-8601"
},
"usage": {
"source": "otel|transcript|manual-unavailable",
"sessions": []
},
"ui": {
"lastSelectedTab": "session"
}
}

Rule: if this file is deleted, the app can regenerate it from Claude files plus current app rules.

8. Usage and OpenTelemetry design

Because you rejected a secondary store, the app must not invent a hidden usage ledger. Instead, it should use a derived-file model.

8.1 Principles
Claude files remain authoritative.
Usage views are marked with provenance:
official-live
derived-from-otel
derived-from-session-artifacts
unavailable
The app never claims billing-grade accuracy unless the source supports it.
8.2 Recommended OTel integration

The best compliant design is:

The app exposes UI for managing Claude session environment variables in settings.json, including OTel-related environment entries where the user wants them. Anthropic’s own settings example shows Claude session env being set in settings.json, including CLAUDE_CODE_ENABLE_TELEMETRY and OTEL_METRICS_EXPORTER.
The app can optionally configure local-only telemetry export to a file or localhost collector under user control.
The app reads the resulting local telemetry artifacts and writes derived summaries only into:
global app file
per-project .claude/claude-config-manager.json
The Session and Project usage views always show:
source of data,
collection status,
whether totals are exact or estimated.
8.3 Required usage model in the app

Internally, in memory only, the app should normalize usage to:

projectId
sessionId
startedAt
endedAt
model
inputTokens
outputTokens
totalTokens
estimatedCost
sourceKind
sourceEvidence

Then it may persist only the reproducible summary representation to the allowed files.

8.4 Privacy posture

Default posture:

no remote telemetry export,
local processing only,
no prompt body export,
no raw file path export beyond local machine use.

This is consistent with the privacy posture from the original spec while still allowing local OTel integration under explicit user control.

9. User interface
   9.1 Sidebar

Use:

Managed
User
Project
Session

Not “Global / Project / Session” only, because Managed and User are distinct in real Claude Code.

9.2 Main editors

Use native SwiftUI forms with AppKit-backed editors where needed.

Views:

structured settings editor,
raw JSON side-by-side mode,
Markdown instruction viewer with import graph,
hook event browser,
MCP server inspector,
agent/skill frontmatter editor,
usage provenance panel.
9.3 Conflict presentation

Every resolved field should display:

current value,
winner,
overridden sources,
merge rule,
write target. 10. Filesystem and save model
10.1 Reads

The app rescans relevant files:

when opening project,
on manual refresh,
on external file change,
before save.
10.2 Writes

All writes must:

validate in memory,
render canonical output,
write temp file,
fsync,
replace original atomically,
refresh resolver.
10.3 No multi-file partial commit

If a logical edit spans multiple Claude files, the app must preview all target files first and then apply a controlled commit sequence. On failure, it must stop and clearly report what changed and what did not.

11. Validation

Validation tiers:

11.1 Syntax
JSON parse
YAML frontmatter parse
Markdown import token parse
11.2 Schema
official Claude settings schema when applicable
hook structure validation
.mcp.json structural validation
skill and agent frontmatter validation
11.3 Semantic
duplicate names
bad precedence assumptions
unreachable imports
invalid tool syntax
unresolvable env expansion in MCP
hook matcher issues
illegal field-at-scope combinations such as autoMemoryDirectory in shared project settings 12. App Store compliance
App Sandbox enabled
user-selected folder access only
security-scoped bookmarks stored in the single global app file
no embedded browser app shell
no arbitrary remote execution feature marketed as core app behavior
local processing first 13. Technical architecture

Platform

Swift
SwiftUI
targeted AppKit bridging

Core modules

ScopeResolver
SettingsParser
ClaudeMdResolver
HookResolver
McpResolver
AgentSkillParser
ValidationEngine
AtomicWriter
UsageDeriver
ProjectRegistry

Persistence

no SQLite
no Core Data
JSON/Markdown only
one global app file
one per-project app file 14. Key corrections versus v2

I want you to create a build plan and include these reccomendaions :

replace Global with distinct Managed and User scopes,
add Local project settings as a separate settings source,
stop treating all settings as if they belong in settings.json,
model ~/.claude.json and .mcp.json explicitly,
distinguish CLAUDE.md from auto memory,
add agents and skills as first-class file types,
replace database-backed token ideas with derived-file summaries,
move to native SwiftUI-first UI,
make the Session view a deterministic resolver output.
and include a feature that allows the setting of the global settings root folder and likewise for projects.

module breakdown,
file format test fixtures,
resolver rules,
save transaction design,
and milestone sequencing.

# Agent Framework — Coding Sub-Agent Handoff Guide

## Purpose

This document provides the shared framework that all coding sub-agents must follow when implementing any packet from the implementation plan. Each packet also has its own spec file in `Documents/Specs/` that describes the specific work.

**Before starting any packet, read this document first, then the packet-specific spec.**

---

## 1. Loading Sequence

Every agent session must begin by loading context in this order:

1. **This file** (`Documents/AGENT_FRAMEWORK.md`) — shared conventions
2. **`Documents/PROJECT_INDEX.md`** — product goal, scope model, module map
3. **`Documents/IMPLEMENTATION_PLAN_V2.md`** — the specific packet description
4. **`Documents/Specs/<packet-spec>.md`** — the packet's detailed spec
5. **Any handoff doc** from predecessor packets: `Documents/<PACKET_ID>-handoff.md`
6. **`CLAUDE.md`** at the project root — build/test commands and coding standards
7. **The actual source files** listed in the spec's "Files to read" section

Do not start writing code until all relevant context is loaded.

---

## 2. Project Structure

```
ClaudeConfigManager/
├── App/                          # App shell, router, sidebar
│   ├── ClaudeConfigManagerApp.swift
│   ├── AppRouter.swift
│   ├── AppBootstrapState.swift
│   ├── SidebarDestination.swift
│   ├── SidebarState.swift
│   └── RootSplitView.swift
├── Core/
│   └── Models/                   # Shared model types
│       └── ScopeScreenModel.swift
├── Features/                     # Per-scope SwiftUI views
│   ├── Managed/
│   │   └── ManagedScopeView.swift
│   ├── User/
│   │   └── UserScopeView.swift
│   ├── Project/
│   │   └── ProjectScopeView.swift
│   ├── Session/
│   │   └── SessionScopeView.swift
│   └── Shared/
│       └── ScopePlaceholderView.swift
└── Infrastructure/
    ├── Parsers/                  # File format parsers
    │   ├── SettingsParser.swift
    │   ├── ClaudeJsonParser.swift
    │   ├── AgentParser.swift
    │   └── SkillParser.swift
    ├── Discovery/                # File system scanning
    │   ├── RootLocator.swift
    │   ├── RootResolutionModels.swift
    │   └── WorkspaceScanner.swift
    ├── Bookmarks/                # macOS security-scoped bookmarks
    │   ├── BookmarkStore.swift
    │   ├── BookmarkPersistence.swift
    │   ├── BookmarkModels.swift
    │   └── FolderSelectionService.swift
    └── Resolver/                 # Resolution models and merge logic
        └── ResolverModels.swift

ClaudeConfigManagerTests/
├── Parsers/                      # Parser unit tests
├── Discovery/                    # Scanner/locator tests
├── Resolver/                     # Resolver tests
├── Bookmarks/                    # Bookmark tests
└── Fixtures/                     # Test fixture files
    ├── parsers/<parser>/<case>/input/ + expected/
    ├── resolvers/<family>/<case>/input/ + expected/
    ├── validation/<family>/<case>/input/ + expected/
    ├── session/<case>/input/ + expected/
    └── shared/<family>/<case>/
```

---

## 3. Coding Standards

### Language and platform
- Swift 5.9+, targeting macOS 14+
- SwiftUI for all views
- `@MainActor` for observable state classes

### Naming conventions
- New Swift files: `<Purpose><Layer>.swift` (e.g., `ParsedSandboxConfig.swift`, `ManagedSettingsLocator.swift`)
- Test files: `<TestedType>Tests.swift`
- Fixture directories: `Fixtures/<family>/<case_id>/input/<filename>` and `expected/<filename>`

### Parser patterns
- Parsers return `ParseResult<T>` with typed `value` and `issues: [SyntaxIssue]` array
- All parsers preserve unknown fields in raw form (`unknownFields` / `rawObject`)
- Issue codes must be descriptive: `.invalidFieldType(key, expected, got)` not `.invalidField`
- Use `JSONValue` for untyped/flexible data, never `Any`
- Use `SyntaxIssue.Severity`: `.info` for preserved keys, `.warning` for type mismatches, `.error` for structural problems

### Resolver patterns
- `ResolutionScope` enum defines precedence: managed > cli > projectLocal > project > user
- `MergeMethod` specifies per-key behavior: `selectHighestPrecedence`, `replace`, `deepMergeObject`, `append`, `appendUnique`, `setUnion`
- Every resolved value must carry a `ResolutionTrace` with participants, overridden sources, and notes
- Resolution issues use `ResolutionIssue` with typed codes

### Validation patterns
- Schema validation: type/shape/range checks within a single document
- Semantic validation: cross-key and cross-scope checks
- Both produce `ValidationIssue` with code, severity, category, message, source reference
- Validation is separate from parsing — parsers should not reject structurally valid but semantically questionable values

### View patterns
- Session views consume projected/resolved data, never raw parsed data
- Views show provenance (which source contributed each value)
- Views show issues inline where relevant

---

## 4. Testing Requirements

### Every packet must:
1. Add fixture files for new parsing (valid and invalid cases)
2. Add unit tests for all new parsing/validation logic
3. Run the full test suite and ensure zero regressions
4. Test file structure: `Fixtures/<parser>/<case_name>/input/` and `expected/`

### Fixture format
```
Fixtures/
└── parsers/
    └── settings/
        └── valid_sandbox/
            ├── input/
            │   └── settings.json
            └── expected/
                └── parser_issues.json    # { "codes": [] } for valid, or list of expected codes
```

### Expected issue format
```json
{
  "codes": ["typeMismatch", "invalidFieldType"]
}
```

### Build and test commands
```bash
# Build
xcodebuild build -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager -destination 'platform=macOS' -quiet

# Test
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager -destination 'platform=macOS' -quiet

# Build and test together (recommended)
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager -destination 'platform=macOS' -quiet 2>&1 | tail -20
```

---

## 5. Critical Rules

1. **NEVER break existing tests.** Run the full suite after changes.
2. **NEVER modify the Xcode project file structure manually.** Add files through the file system and let Xcode folder references pick them up.
3. **NEVER remove or rename existing public API** without backward compatibility.
4. **Keep each packet scoped.** Do not implement work belonging to other packets.
5. **Use `JSONValue` for untyped data**, not `Any`.
6. **Preserve unknown fields** for forward compatibility.
7. **Managed-only keys** must be flagged in the registry/parser so validation can warn when they appear in non-managed scopes.
8. **Array settings merge across scopes** (concatenated + deduplicated). This must be reflected in merge hints.

---

## 6. Handoff Document

After completing a packet, create `Documents/<PACKET_ID>-handoff.md` with:

- Files created or modified (list each)
- Key decisions and assumptions made
- Any issues encountered or open questions
- Recommended next packet

---

## 7. Packet Dependency Graph

```
G1 -> G2

After G2 (all can proceed in parallel):
├── Managed track: M1 -> M2 -> M3 -> M4
├── Permissions/MCP track: P1, P2, P3 (parallel)
├── Hooks track: H1 -> H2 -> H3
└── Settings family track: S1, S2, S3, S4, J1, U1, U2 (parallel)

After app shell and discovery foundations (independent of parser pipeline):
└── Runtime track: T1, T2, T3 (can proceed in parallel); T4 depends on T1 + T2

After parser and managed tracks are stable:
└── Resolver track: R1 -> R2 -> R3

After resolver track:
└── Session UI track: V1, V2, V3, V4

After parser/resolver stabilization:
└── Validation track: E4, E5

Optional final track:
└── FC1
```

---

## 8. Key Reference: Settings Precedence

From highest to lowest (per official Claude Code docs, March 2026):

1. **Managed** (server-managed > MDM/OS policy > file-based) — cannot be overridden
2. **Command line arguments** — temporary session overrides
3. **Local** (`.claude/settings.local.json`) — personal project overrides
4. **Project** (`.claude/settings.json`) — team-shared
5. **User** (`~/.claude/settings.json`) — personal global

Array-valued settings **merge across scopes** (concatenated + deduplicated), not replaced.

---

## 9. Key Reference: Hook Event Catalog

25 events as of March 2026:

| Event | Matchers | Blocks | Context Inject | Notes |
|-------|----------|--------|----------------|-------|
| SessionStart | startup, resume, clear, compact | No | No | |
| SessionEnd | clear, resume, logout, prompt_input_exit, bypass_permissions_disabled, other | No | No | |
| UserPromptSubmit | — | Yes | Yes | Prompt erasure: `{"decision":"block"}` erases prompt |
| PreToolUse | tool name (regex) | Yes | Yes | Can modify tool parameters |
| PostToolUse | tool name (regex) | Yes | Yes | Can annotate tool results |
| PostToolUseFailure | tool name (regex) | No | No | |
| PermissionRequest | tool name | Yes | No | |
| Notification | permission_prompt, idle_prompt, auth_success, elicitation_dialog | No | No | |
| Stop | — | Yes | Yes | Can provide continuation instructions |
| StopFailure | rate_limit, authentication_failed, billing_error, invalid_request, server_error, max_output_tokens, unknown | No | No | |
| SubagentStart | agent type | No | No | |
| SubagentStop | agent type | Yes | No | |
| PreCompact | manual, auto | No | No | |
| PostCompact | manual, auto | No | No | |
| InstructionsLoaded | session_start, nested_traversal, path_glob_match, include, compact | No | No | |
| ConfigChange | user_settings, project_settings, local_settings, policy_settings, skills | Yes | No | |
| WorktreeCreate | — | Yes | No | |
| WorktreeRemove | — | No | No | |
| Elicitation | MCP server name | Yes | No | |
| ElicitationResult | MCP server name | Yes | No | |
| CwdChanged | — | No | No | |
| FileChanged | filename/basename | No | No | |
| TaskCreated | — | Yes | No | |
| TaskCompleted | — | Yes | No | |
| TeammateIdle | — | Yes | No |

---

## 10. Key Reference: Hook Handler Types

| Type | Required field | Specific properties |
|------|---------------|-------------------|
| `command` | `command` | `shell` ("bash"/"powershell"), `async` (bool) |
| `http` | `url` | `headers` (object, supports `$VAR` interpolation), `allowedEnvVars` (string array) |
| `prompt` | `prompt` | `model` (string) |
| `agent` | `prompt` | `model` (string) |

**Common properties** (all types): `type`, `timeout` (seconds), `statusMessage`, `if`, `once`

---

## 11. Key Reference: Full Settings.json Surface

### General & environment
`apiKeyHelper`, `autoMemoryDirectory`, `autoMemoryEnabled`, `cleanupPeriodDays`, `companyAnnouncements`, `env`, `includeGitInstructions`, `includeCoAuthoredBy` (deprecated), `claudeMdExcludes`

### Attribution
`attribution.commit`, `attribution.pr`

### Model & AI behavior
`model`, `availableModels`, `modelOverrides`, `effortLevel`, `alwaysThinkingEnabled`, `fastMode`, `fastModePerSessionOptIn`, `feedbackSurveyRate`, `agent`

### Auto mode
`autoMode`, `disableAutoMode`, `useAutoModeDuringPlan`

### Permissions (nested under `permissions`)
`allow`, `deny`, `ask`, `defaultMode`, `additionalDirectories`, `disableBypassPermissionsMode`

**`defaultMode` schema drift tolerance:** Accept any string value. Known values: `default`, `acceptEdits`, `plan`, `auto`, `dontAsk`, `bypassPermissions`, `delegate` (experimental). Unknown values → info-level issue, not error.

### Permissions (top-level)
`allowManagedPermissionRulesOnly`

### Hooks
`hooks` (event → matcher group → handler array), `disableAllHooks`, `allowManagedHooksOnly`, `allowedHttpHookUrls`, `httpHookAllowedEnvVars`

### MCP controls
`allowManagedMcpServersOnly`, `enableAllProjectMcpServers`, `enabledMcpjsonServers`, `disabledMcpjsonServers`, `allowedMcpServers`, `deniedMcpServers`

**MCP restriction rules** (`allowedMcpServers`/`deniedMcpServers`) use discriminated union shapes:
- `{ "serverName": "github" }` — match by name
- `{ "serverCommand": ["npx", ...] }` — match by command array
- `{ "serverUrl": "https://..." }` — match by URL pattern

### Sandbox (nested under `sandbox`)
`enabled`, `failIfUnavailable`, `autoAllowBashIfSandboxed`, `excludedCommands`, `allowUnsandboxedCommands`, `enableWeakerNestedSandbox`, `enableWeakerNetworkIsolation`

### Sandbox filesystem (nested under `sandbox.filesystem`)
`allowWrite`, `denyWrite`, `denyRead`, `allowRead`, `allowManagedReadPathsOnly`

### Sandbox network (nested under `sandbox.network`)
`allowUnixSockets`, `allowAllUnixSockets`, `allowLocalBinding`, `allowedDomains`, `allowManagedDomainsOnly`, `httpProxyPort`, `socksProxyPort`

### Plugins & marketplaces
`enabledPlugins`, `extraKnownMarketplaces`, `strictKnownMarketplaces`, `blockedMarketplaces`, `pluginTrustMessage`, `channelsEnabled`, `allowedChannelPlugins`

### Advanced read-only keys (internal/diagnostic)
`pluginConfigs`, `skippedPlugins`, `skippedMarketplaces`

### Authentication & helpers
`forceLoginMethod`, `forceLoginOrgUUID`, `otelHeadersHelper`, `awsAuthRefresh`, `awsCredentialExport`

### UI & session experience
`statusLine` (with `padding`), `fileSuggestion`, `language`, `respectGitignore`, `outputStyle`, `defaultShell`, `voiceEnabled`, `prefersReducedMotion`, `spinnerVerbs`, `spinnerTipsEnabled`, `spinnerTipsOverride`, `showClearContextOnPlanAccept`

### Worktree (nested under `worktree`)
`sparsePaths`, `symlinkDirectories`

### Other operational
`plansDirectory`, `autoUpdatesChannel`, `disableDeepLinkRegistration`

### ~/.claude.json-only global config keys (NOT settings.json)
`autoConnectIde`, `autoInstallIdeExtension`, `editorMode`, `showTurnDuration`, `terminalProgressBarEnabled`, `teammateMode`

---

## 12. Key Reference: Managed Instruction Sources

In addition to managed settings JSON files, managed policy includes:

- `/Library/Application Support/ClaudeCode/CLAUDE.md` — managed instruction source that applies to all Claude Code sessions on the machine
- Discovered alongside `managed-settings.json` and `managed-mcp.json` in M1
- Displayed in V4 Managed scope view with presence/absence/inaccessible state

---

## 13. Key Reference: MCP Transport Types

| Transport | Status | Key indicator | Notes |
|-----------|--------|--------------|-------|
| `stdio` | Primary | Has `command` field | Child process, stdin/stdout |
| `http` | Current | Has `url`, no `command` | Streamable HTTP protocol |
| `sse` | Deprecated | Explicit `"transport": "sse"` | Server-Sent Events, superseded by http |
| `plugin` | Special | Has `pluginId` | Plugin-provided, not user-configured |

---

## 14. Key Reference: Runtime Track (T1–T4)

The runtime track (Phase 12) provides session-level observability independent of the parser/resolver pipeline:

- **T1**: Runtime session snapshot — models the documented status-line stdin JSON schema (snake_case, nested objects for model/cost/context_window/rate_limits); best-effort transcript-based discovery since Claude Code does not write snapshot files to disk
- **T2**: Transcript discovery — browse `~/.claude/projects/` transcripts with explicit primary-session vs subagent classification (JSONL format is undocumented; treat record schema as best-effort from on-disk samples)
- **T3**: OTel config display (optional) — detect and display OpenTelemetry configuration from env vars and `otelHeadersHelper` (string script path); use it for configuration/privacy observability and correlation reference data, not collector querying
- **T4**: Usage views — aggregate token/cost summaries from local transcripts (depends on T1 + T2)

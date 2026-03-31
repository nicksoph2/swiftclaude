# Claude Config Manager - Gap Closure Implementation Plan

## Overview

This plan updates the original implementation roadmap using the current codebase plus a doc verification pass against the current Claude Code documentation as of March 31, 2026.

The goal remains the same: make Claude Config Manager a trustworthy native macOS app that inspects, validates, resolves, and eventually edits the real Claude Code configuration surface without introducing a shadow source of truth.

## What changed in this revision

The original plan was directionally correct, but several recommendations needed correction or expansion:

- Managed settings precedence is now treated as:
  1. server-managed settings
  2. MDM / OS policy
  3. file-based managed settings
- Managed settings are above command-line arguments
- Managed tiers do not all merge together
- Only the file-based managed tier merges internally
- Hook coverage must follow the modern Claude Code event model, not the older 23-event approximation in the gap analysis
- Hook handler types must include `command`, `http`, `prompt`, and `agent`
- Permissions parsing must use modern field names like `disableBypassPermissionsMode`
- MCP restriction keys require typed rule objects, not only string arrays
- Sandbox configuration is a nested object family and needs a stronger dedicated model
- Plugin marketplace settings are broader than the original plan assumed
- Several settings previously treated as stale are currently documented and should remain first-class:
  - `alwaysThinkingEnabled`
  - `defaultShell`
  - `channelsEnabled`
  - `allowedChannelPlugins`
- Several additional settings families now deserve first-class treatment:
  - `cleanupPeriodDays`
  - `companyAnnouncements`
  - `env`
  - `useAutoModeDuringPlan`
  - `disableDeepLinkRegistration`
  - `fastMode`
  - `fastModePerSessionOptIn`
  - `feedbackSurveyRate`
  - `outputStyle`
  - `statusLine`
  - `fileSuggestion`
  - `plansDirectory`
  - `autoUpdatesChannel`
  - `prefersReducedMotion`
  - `spinnerVerbs`
  - `spinnerTipsEnabled`
  - `spinnerTipsOverride`
  - `worktree.sparsePaths`
- The following settings were identified as gaps during the March 31 2026 comprehensive review and are now tracked in the appropriate packets:
  - `worktree.symlinkDirectories` (new worktree key, added to U2)
  - `voiceEnabled` (voice dictation toggle, added to U1)
  - `defaultShell` (terminal shell selection, added to U1)
  - `showClearContextOnPlanAccept` (plan accept screen option, added to U2)
  - `agent` (named subagent for main thread, added to S1)
  - `teammateMode` (agent team display mode, ~/.claude.json key, added to J1)
  - `autoConnectIde` (IDE auto-connect, ~/.claude.json key, added to J1)
  - `autoInstallIdeExtension` (IDE extension auto-install, ~/.claude.json key, added to J1)
  - `editorMode` (vim/normal key binding, ~/.claude.json key, added to J1)
  - `showTurnDuration` (turn duration display, ~/.claude.json key, added to J1)
  - `terminalProgressBarEnabled` (terminal progress bar, ~/.claude.json key, added to J1)
  - `enableAllProjectMcpServers` (MCP auto-approve, added to P2)
  - `sandbox.failIfUnavailable` (hard gate for sandbox, added to S3)
  - `sandbox.allowUnsandboxedCommands` (escape hatch control, added to S3)
  - `sandbox.network.httpProxyPort` (custom HTTP proxy, added to S3)
  - `sandbox.network.socksProxyPort` (SOCKS5 proxy, added to S3)
  - `sandbox.enableWeakerNetworkIsolation` (macOS TLS trust, added to S3)
- Hook properties requiring correction:
  - `timeout` is specified in seconds in the official docs, not milliseconds; the current parser uses `timeoutMs` which must be corrected
  - `once` (boolean, skills-only) and `shell` ("bash" or "powershell") are newly documented hook properties
- Attribution model expansion:
  - The `attribution` setting is now an object with `commit` and `pr` string sub-keys, not just `includeCoAuthoredBy`
  - `includeCoAuthoredBy` is deprecated but should remain parseable for backward compatibility

## Current state

- The app shell exists
- Bookmark and discovery foundations exist
- Parsers exist for settings, Claude JSON, MCP, CLAUDE.md, agents, and skills
- Resolver models and Session UI scaffolding exist
- Managed scope is still effectively unimplemented
- Settings parsing still covers only a fraction of the modern surface
- Hook support is materially behind current docs
- Sandbox coverage remains effectively absent

## Target state

The target state is full, trustworthy coverage of Claude Code’s active configuration surface on macOS, including:

- discovery of all relevant Claude-owned files and managed sources
- schema-driven parsing with forward compatibility
- deterministic resolution with provenance
- clear validation and diagnostics
- a read-only but complete Session view
- a meaningful Managed scope view
- safe editing only after the read-first core is trustworthy

---

## How to use this plan

For each packet:

1. Load `Documents/PROJECT_INDEX.md`
2. Load the relevant section doc
3. Load this plan
4. Load any packet-specific handoff doc if one exists
5. Read the existing source files and tests the packet will touch
6. Implement, test, and produce a handoff doc

All packet work should preserve these product rules:

- Claude-owned files are authoritative
- no shadow database
- Session is computed, not persisted
- Session remains read-only
- provenance and diagnostics must stay first-class
- parsers preserve unsupported keys when possible
- resolver rules are explicit and testable
- App Store builds must not rely on privileged helpers, admin elevation, or silent access to protected folders
- user/project folder access must be obtained through user-mediated folder selection and security-scoped bookmarks
- managed and user folder inspection remains read-only unless a later editing phase explicitly changes that
- inaccessible Claude-owned locations must surface as explicit state, never as silent omission

---

## Phase 1: Schema-Driven Parser Refactor (Foundation)

This phase still comes first. The app should not keep scaling by adding one-off properties for each new key.

### Packet G1: Settings Key Registry and Schema-Driven Parsing

**Goal**: Replace bespoke settings parsing with a schema-driven registry that can represent the modern Claude Code settings surface while preserving existing behavior.

**Deliverables**:
- `SettingsKeyDefinition`
- `SettingsKeyRegistry`
- a registry-backed `SettingsDocumentValue` storage model
- compatibility shims for current named properties
- typed metadata for:
  - key path
  - category
  - expected shape
  - scope restrictions
  - merge hints
  - managed-only status where applicable

**Expanded recommendation**:
- Include currently verified settings families, not only the original 70-ish keys from the gap analysis
- Design the registry to support nested object families such as `sandbox`, `permissions`, `statusLine`, `fileSuggestion`, `worktree`, and plugin marketplace structures
- Keep unknown top-level and nested keys preservable for forward compatibility

**Acceptance criteria**:
- existing supported keys parse exactly as before
- unknown keys still emit info-level preserved-key issues
- known keys with wrong types emit warnings
- registry coverage test reflects the current verified settings surface, not the stale original estimate

### Packet G2: Typed Accessor Layer for SettingsDocumentValue

**Goal**: Add typed accessors on top of the registry-backed store so the rest of the app can consume settings safely.

**Deliverables**:
- scalar accessors
- object accessors
- structured family accessors
- backwards-compatible named properties for existing codepaths

**Expanded recommendation**:
- Add grouped accessors for:
  - model settings
  - permission settings
  - hook policy settings
  - MCP policy settings
  - plugin settings
  - sandbox settings
  - UI and spinner settings
  - worktree settings
  - memory settings

**Acceptance criteria**:
- all existing parser tests still pass
- new accessors safely return nil on absent or wrong-type values

---

## Phase 2: Critical Gap - Managed Settings Tier

This remains the single highest-value gap, but the plan must follow current managed precedence semantics.

### Packet M1: Managed Settings Discovery (macOS)

**Goal**: Discover managed Claude Code files on macOS.

**Deliverables**:
- discovery of `/Library/Application Support/ClaudeCode/managed-settings.json`
- discovery of `managed-settings.d/*.json`
- discovery of `managed-mcp.json`
- discovery of `/Library/Application Support/ClaudeCode/CLAUDE.md` (managed instruction source)
- managed directory/file kinds integrated into discovery models

**Expanded recommendation**:
- Keep the macOS implementation explicit, but structure it so platform differences can be introduced later without reworking discovery contracts
- Treat missing paths as normal and inaccessible paths as attributable discovery issues
- For App Store-safe builds, tolerate that `/Library/Application Support/ClaudeCode/` may be unreadable inside the sandbox

### Packet M2: MDM Plist Reading

**Goal**: Read MDM-delivered managed settings from `com.anthropic.claudecode`.

**Deliverables**:
- `MDMPolicyReader`
- plist-to-`JSONValue` normalization
- testable injection for policy lookup

**Expanded recommendation**:
- Preserve issue reporting for unsupported plist types
- Keep the output generic enough to feed the same settings parser/validator pathways used for file-based managed JSON
- Keep MDM/policy inspection strictly read-only

### Packet M3: Managed Tier Resolution and Precedence

**Goal**: Resolve the managed tier correctly according to current docs.

**Corrected recommendation**:
- Do not merge all managed sources together
- Resolve managed source tiers in this order:
  1. server-managed settings
  2. MDM / OS policy
  3. file-based managed settings
- Only the file-based tier merges internally
- Within the file-based tier:
  - merge `managed-settings.json`
  - merge `managed-settings.d/*.json` deterministically
  - document and test the exact override order used by Claude Code docs

**Deliverables**:
- `ManagedSettingsResolver`
- representation of active managed source tier
- file-based merge logic
- managed tier integration into the main resolver as highest precedence
- managed MCP integration path

**Acceptance criteria**:
- if server-managed settings exist, MDM and file-based managed settings do not participate
- if MDM exists and server-managed settings do not, file-based managed settings do not participate
- file-based managed settings merge deterministically
- Session resolved state changes when managed sources are present

### Packet M4: Sandbox Entitlements and Managed Access Fallback

**Goal**: Handle macOS sandbox requirements for managed paths without breaking the user-facing app.

**Deliverables**:
- entitlement update if viable
- graceful fallback if direct access is denied
- explicit UX in Managed scope for access problems

**Expanded recommendation**:
- treat access-denied as a first-class state, not a silent omission
- do not regress bookmark-based user/project root flows
- prefer `com.apple.security.files.user-selected.read-only` plus security-scoped bookmarks for user-configurable folders
- do not add any privileged helper, installer, or admin-write path for managed inspection in an App Store build

---

## Phase 3: Critical Gap - Permissions and MCP Controls

### Packet P1: Modern Permissions Parsing

**Goal**: Expand permissions parsing to match current Claude Code settings.

**Corrected recommendation**:
- model:
  - `permissions.allow`
  - `permissions.deny`
  - `permissions.ask`
  - `permissions.defaultMode`
  - `permissions.additionalDirectories`
  - `permissions.disableBypassPermissionsMode`
  - top-level `allowManagedPermissionRulesOnly`
- do not use the stale `permissions.disableBypass` field name
- do not assume the default mode enum is only `allow/deny/ask`

**Deliverables**:
- updated `ParsedPermissions`
- modern enum/value validation
- fixture coverage for valid and invalid mode values

### Packet P2: MCP Server Control Keys

**Goal**: Parse all current MCP control settings.

**Corrected recommendation**:
- `enableAllProjectMcpServers` — boolean (auto-approve all MCP servers in project `.mcp.json` files)
- `enabledMcpjsonServers` and `disabledMcpjsonServers` remain simple string arrays (approve/reject specific servers by name)
- `allowedMcpServers` and `deniedMcpServers` should be modeled as **mutually exclusive discriminated union shapes**:
  - **Shape 1**: `{ "serverName": "github" }` — match by server name only
  - **Shape 2**: `{ "serverCommand": ["npx", "-y", "@modelcontextprotocol/server-github"] }` — match by stdio command array (NOT string)
  - **Shape 3**: `{ "serverUrl": "https://api.example.com/*" }` — match by remote URL pattern (NOT nested under serverName)
  - Exactly one discriminator key (`serverName`, `serverCommand`, or `serverUrl`) must be present per rule
- `allowManagedMcpServersOnly` should retain managed-only semantics (only managed `allowedMcpServers` are respected; `deniedMcpServers` still merges from all sources)
- note: deny rules take precedence over allow rules per the official docs

**Deliverables**:
- typed MCP restriction rule model (discriminated union struct with exactly one of three fields non-nil)
- parser support for three distinct rule shapes
- validation enforcing discriminated union (exactly one discriminator per rule, `serverCommand` must be array)
- scope restriction validation (`allowManagedMcpServersOnly` only valid in managed settings)
- fixture coverage for all three discriminated shapes and malformed variants

### Packet P3: MCP Transport and Per-Server Policy Coverage

**Goal**: Normalize modern MCP server definitions across `.mcp.json`, `~/.claude.json`, and managed MCP.

**Expanded recommendation**:
- preserve current stdio parsing
- support remote URL-based server definitions with headers
- keep transport modeling explicit enough for Session UI and resolver decisions
- preserve room for future transport variations without overfitting to speculative unsupported cases

**Deliverables**:
- normalized `McpServerConfig`
- parser updates for all current MCP sources
- tests for stdio and remote configurations

---

## Phase 4: Critical Gap - Complete Hook System

The original hook phase is the most outdated part of the plan and needs the strongest rewrite.

### Packet H1: Current Hook Event Catalog

**Goal**: Replace the stale hook event assumptions with the current Claude Code hook event model.

**Corrected recommendation**:
- stop using the earlier “23 event types” list from the gap analysis as the source of truth
- model the current documented event family, including:
  - `SessionStart`
  - `SessionEnd`
  - `UserPromptSubmit`
  - `PreToolUse`
  - `PostToolUse`
  - `PostToolUseFailure`
  - `PermissionRequest`
  - `Notification`
  - `Stop`
  - `StopFailure`
  - `SubagentStart`
  - `SubagentStop`
  - `PreCompact`
  - `PostCompact`
  - `InstructionsLoaded`
  - `ConfigChange`
  - `WorktreeCreate`
  - `WorktreeRemove`
  - `Elicitation`
  - `ElicitationResult`
  - `CwdChanged`
  - `FileChanged`
  - `TaskCreated`
  - `TaskCompleted`
  - `TeammateIdle`
  - `Setup` where retained for schema-backed forward compatibility
- unknown future events should be preserved with warnings, not rejected hard

### Packet H2: Hook Handler Types

**Goal**: Support all current hook handler types.

**Corrected recommendation**:
- handler types must include:
  - `command`
  - `http`
  - `prompt`
  - `agent`
- do not model HTTP hooks with arbitrary method/body fields unless the current docs or schema support them
- include current shared fields such as timeout and status message where supported

**Deliverables**:
- explicit hook handler enum/model
- validation rules per handler type
- transport-specific tests

### Packet H3: Hook Properties and Global Hook Controls

**Goal**: Add remaining hook properties and global controls.

**Expanded recommendation**:
- cover:
  - top-level `disableAllHooks`
  - per-hook `if` (permission rule syntax filter, tool events only)
  - per-hook `allowedEnvVars` for HTTP hooks
  - per-hook `async` (boolean, command hooks only)
  - per-hook `statusMessage` (custom spinner message)
  - per-hook `once` (boolean, skills-only — run only once per session)
  - per-hook `shell` ("bash" or "powershell", command hooks only)
  - per-hook `timeout` in **seconds** (not milliseconds — this corrects the current `timeoutMs` field in `ParsedHookAction`)
  - per-hook `model` (string, prompt and agent hooks only — model to use for evaluation)
  - per-hook `headers` (object, HTTP hooks only — supports `$VAR_NAME` interpolation)
- **Critical fix**: the current parser models `timeoutMs: Int?` but the official docs specify `timeout` in seconds. This must be corrected:
  - rename the field from `timeoutMs` to `timeout`
  - update the JSON parsing key from `"timeoutMs"` to `"timeout"`
  - update all fixture data and tests accordingly
  - the type remains `Int?` (seconds, not milliseconds)
- keep room for event-specific output or decision metadata in resolver/UI work, but do not overload the base parser with runtime semantics

**Deliverables**:
- updated `ParsedHookAction` with all properties above
- `timeoutMs` → `timeout` migration
- validation for property/handler-type compatibility (e.g., `async` only valid on command hooks, `model` only on prompt/agent hooks)
- fixture coverage for each handler type with its specific properties

**Acceptance criteria**:
- current docs examples round-trip into the typed hook model
- invalid property combinations produce attributable issues
- `timeoutMs` no longer appears anywhere in the codebase

---

## Phase 5: High Priority - Model, Auth, Sandbox, Plugins

### Packet S1: Model and AI Behavior Keys

**Goal**: Parse current model-related settings.

**Expanded recommendation**:
- include:
  - `model` — string (model ID override, e.g., `"claude-sonnet-4-6"`)
  - `availableModels` — string array (restrict selectable models via `/model`, `--model`, Config)
  - `modelOverrides` — object (map Anthropic model IDs to provider-specific IDs, e.g., Bedrock ARNs)
  - `effortLevel` — enum: `"low"`, `"medium"`, `"high"` (persisted effort level)
  - `alwaysThinkingEnabled` — boolean (enable extended thinking by default)
  - `fastMode` — boolean (fast mode toggle)
  - `fastModePerSessionOptIn` — boolean (fast mode does not persist across sessions)
  - `feedbackSurveyRate` — number, 0–1 (session quality survey probability)
  - `agent` — string (run main thread as a named subagent; applies that subagent's system prompt, tool restrictions, and model)
- keep existing `autoMode`-family support intact
- keep `alwaysThinkingEnabled` in scope unless a newer primary source removes it
- validate `effortLevel` as a closed enum
- validate `feedbackSurveyRate` as a number in range [0, 1]

**Deliverables**:
- typed fields for all 9 keys above
- enum validation for `effortLevel`
- range validation for `feedbackSurveyRate`
- object shape validation for `modelOverrides` (string → string map)
- fixture coverage for valid values, invalid enums, and out-of-range numbers

### Packet S2: Authentication and Identity Keys

**Goal**: Parse current authentication-related settings that are actually verifiable.

**Corrected recommendation**:
- prioritize:
  - `forceLoginMethod`
  - `forceLoginOrgUUID`
  - `otelHeadersHelper`
  - continued support for `apiKeyHelper`
- include helper-script keys where verified:
  - `awsAuthRefresh`
  - `awsCredentialExport`
- `defaultShell` is currently documented, but it belongs with terminal/input behavior rather than authentication

### Packet S3: Sandbox Configuration

**Goal**: Add a dedicated nested sandbox model that reflects the current settings surface.

**Corrected recommendation**:
- do not keep treating sandbox settings as a handful of flat keys
- model the full sandbox key inventory (21 keys across 3 levels):

  **Top-level sandbox keys:**
  - `sandbox.enabled` — boolean
  - `sandbox.failIfUnavailable` — boolean (hard gate: exit with error if sandbox cannot start)
  - `sandbox.autoAllowBashIfSandboxed` — boolean (default: true)
  - `sandbox.excludedCommands` — string array (commands that run outside sandbox)
  - `sandbox.allowUnsandboxedCommands` — boolean (controls `dangerouslyDisableSandbox` escape hatch)
  - `sandbox.enableWeakerNestedSandbox` — boolean (Linux/WSL2 only, reduces security)
  - `sandbox.enableWeakerNetworkIsolation` — boolean (macOS only, allows TLS trust service access)

  **Filesystem child model (`sandbox.filesystem`):**
  - `sandbox.filesystem.allowWrite` — string array (additional writable paths, merged across scopes)
  - `sandbox.filesystem.denyWrite` — string array (blocked write paths, merged across scopes)
  - `sandbox.filesystem.denyRead` — string array (blocked read paths, merged across scopes)
  - `sandbox.filesystem.allowRead` — string array (re-allowed read paths within denyRead regions, merged across scopes)
  - `sandbox.filesystem.allowManagedReadPathsOnly` — boolean (managed only: ignore non-managed allowRead)

  **Network child model (`sandbox.network`):**
  - `sandbox.network.allowUnixSockets` — string array (accessible Unix socket paths)
  - `sandbox.network.allowAllUnixSockets` — boolean
  - `sandbox.network.allowLocalBinding` — boolean (macOS only, bind to localhost)
  - `sandbox.network.allowedDomains` — string array (outbound traffic domains, supports wildcards)
  - `sandbox.network.allowManagedDomainsOnly` — boolean (managed only: ignore non-managed domains)
  - `sandbox.network.httpProxyPort` — integer (custom HTTP proxy port)
  - `sandbox.network.socksProxyPort` — integer (custom SOCKS5 proxy port)

  **Path prefix rules** (important for validation):
  - `/` — absolute path from filesystem root
  - `~/` — relative to home directory
  - `./` or no prefix — relative to project root (project settings) or `~/.claude` (user settings)
  - sandbox filesystem paths also merge with `Edit(...)` allow/deny and `Read(...)` deny permission rules

- keep the parsing structured enough for validation and Session UI presentation
- note that array-valued sandbox settings **merge across scopes** (concatenated and deduplicated), not replaced

**Deliverables**:
- `ParsedSandboxConfig` with top-level, filesystem, and network child structs
- path prefix normalization utilities
- merge-across-scopes behavior annotations for the resolver
- fixtures for minimal, full, invalid, and managed-only sandbox shapes
- validation for managed-only keys used outside managed scope

**Scope consideration**: This packet covers 21 keys across nested objects. If implementation time is a concern, it may be split into:
- S3a: top-level sandbox keys + filesystem child model
- S3b: network child model + path prefix normalization + managed-only validation

### Packet S4: Plugin and Marketplace Control Keys

**Goal**: Expand plugin settings to match the modern marketplace model.

**Expanded recommendation**:
- cover:
  - `enabledPlugins`
  - `extraKnownMarketplaces`
  - `strictKnownMarketplaces`
  - `blockedMarketplaces`
  - `pluginTrustMessage`
  - `channelsEnabled`
  - `allowedChannelPlugins`
- support current marketplace source variants such as:
  - github
  - git
  - url
  - npm
  - file
  - directory
  - hostPattern
  - inline/settings-style source if validated during implementation
- treat `pluginConfigs`, `skippedMarketplaces`, and `skippedPlugins` as advanced read-only registry entries — parseable and displayable but flagged as internal/advanced (consistent with G1 spec)

---

## Phase 6: High Priority - ~/.claude.json Completion

### Packet J1: Remaining ~/.claude.json Keys

**Goal**: Expand `~/.claude.json` support carefully without overfitting to stale assumptions.

**Corrected recommendation**:
- keep existing support for:
  - `globalPreferences`
  - `mcp`
  - `trust`
- add the following verified global config keys (these live in `~/.claude.json`, NOT in `settings.json`, and adding them to `settings.json` triggers a schema validation error):
  - `autoConnectIde` — boolean (auto-connect to running IDE from external terminal, default: false)
  - `autoInstallIdeExtension` — boolean (auto-install IDE extension in VS Code terminal, default: true)
  - `editorMode` — enum: `"normal"` or `"vim"` (input prompt key bindings)
  - `showTurnDuration` — boolean (show turn duration messages after responses, default: true)
  - `terminalProgressBarEnabled` — boolean (terminal progress bar in supported terminals, default: true)
  - `teammateMode` — enum: `"auto"`, `"in-process"`, or `"tmux"` (agent team display mode)
- add remaining keys only when they are grounded in:
  - current codebase expectations
  - current fixtures
  - current docs or schema references available at implementation time
- treat this packet as forward-compatible completion work, not speculative key harvesting

**Implementation guidance**:
- the 6 verified global config keys above should be modeled as typed fields on the parsed document, with enum validation where applicable
- these keys should produce a warning-level issue if found in `settings.json` (they do not belong there)
- the existing ClaudeJsonParser already detects settings.json keys placed in claude.json; the reverse detection (claude.json keys placed in settings.json) should also be added
- preserve unsupported keys with issues rather than inventing typed models for unverified keys

**Deliverables**:
- updated `ParsedClaudeJsonDocument` with the 6 new typed fields
- enum validation for `editorMode` and `teammateMode`
- cross-file key placement warnings (claude.json keys in settings.json and vice versa)
- fixture coverage for valid values, invalid enum values, and misplaced keys

---

## Phase 7: Medium Priority - UI/UX, Git, Worktree, and Remaining Settings

### Packet U1: UI/UX and Git Settings

**Goal**: Add the user-facing experience settings that are currently underrepresented.

**Expanded recommendation**:
- cover:
  - `statusLine` — object with `type`, `command`, and optional `padding` fields
  - `fileSuggestion` — object with `type` and `command` fields
  - `language` — string (preferred response language, also sets voice dictation language)
  - `respectGitignore` — boolean (default: true)
  - `outputStyle` — string (output style name)
  - `defaultShell` — enum: `"bash"` (default) or `"powershell"` (terminal shell selection for `!` commands)
  - `voiceEnabled` — boolean (push-to-talk voice dictation)
  - `prefersReducedMotion` — boolean (reduce UI animations for accessibility)
  - `spinnerVerbs` — object with `mode` ("replace" or "append") and `verbs` (string array)
  - `spinnerTipsEnabled` — boolean (default: true)
  - `spinnerTipsOverride` — object with `excludeDefault` (boolean) and `tips` (string array)
- expand the `attribution` model to support the modern structure:
  - `attribution.commit` — string (commit attribution text, empty string hides it)
  - `attribution.pr` — string (PR description attribution text, empty string hides it)
  - preserve backward compatibility with the deprecated `includeCoAuthoredBy` top-level key
  - `attribution` takes precedence over `includeCoAuthoredBy` when both are present
- note: `showTurnDuration` and `terminalProgressBarEnabled` are ~/.claude.json keys, not settings.json keys; they are handled in Packet J1 instead

**Deliverables**:
- typed models for `statusLine`, `fileSuggestion`, `spinnerVerbs`, `spinnerTipsOverride`, and `attribution` object shapes
- enum validation for `defaultShell`
- fixture coverage for each structured object type

### Packet U2: Worktree, Memory, Update, and Remaining Settings

**Goal**: Finish the remaining verified settings families after the major policy and parser work is done.

**Expanded recommendation**:
- prioritize:
  - `worktree.sparsePaths` — string array (sparse-checkout paths for worktrees)
  - `worktree.symlinkDirectories` — string array (directories to symlink from main repo into worktrees to avoid duplication)
  - `plansDirectory` — string (custom plan file storage path, relative to project root)
  - `autoUpdatesChannel` — enum: `"stable"` or `"latest"` (release channel for updates)
  - `cleanupPeriodDays` — integer (session cleanup period, 0 disables persistence entirely)
  - `companyAnnouncements` — string array (startup announcements, cycled randomly)
  - `disableDeepLinkRegistration` — string, value `"disable"` (prevent `claude-cli://` protocol handler registration)
  - `useAutoModeDuringPlan` — boolean (default: true, not read from shared project settings)
  - `showClearContextOnPlanAccept` — boolean (default: false, show clear context option on plan accept screen)
- include remaining low-risk verified keys from current docs/schema after the above are covered
- `autoMemoryEnabled` and `claudeMdExcludes` are first-class registry entries (promoted in G1, they appear in current schema and documentation) and should be parsed with the other verified keys in this packet
- use this packet to close verified coverage gaps, not to carry speculative historical keys forward

**Deliverables**:
- worktree settings modeled as a nested object family with both `sparsePaths` and `symlinkDirectories`
- enum validation for `autoUpdatesChannel`
- special behavior validation for `cleanupPeriodDays` (0 = disable persistence)
- scope restriction validation for `useAutoModeDuringPlan` (not read from shared project settings)

---

## Phase 8: Resolver Integration

### Packet R1: Settings Resolver - New Key Categories

**Goal**: Wire all newly parsed settings families through the resolver with correct precedence, merge rules, and provenance.

**Expanded recommendation**:
- managed settings must be highest precedence
- apply explicit merge behavior per family:
  - replace for most scalars
  - deep merge for relevant objects
  - append-and-dedupe only where the docs imply merging semantics
- preserve managed-only policy semantics for keys like:
  - `allowManagedHooksOnly`
  - `allowManagedPermissionRulesOnly`
  - `allowManagedMcpServersOnly`
  - `strictKnownMarketplaces`
  - `pluginTrustMessage`
  - managed-only network policy keys where applicable

### Packet R2: Hook Resolver Updates

**Goal**: Resolve the modern hook surface into a trustworthy Session representation.

**Expanded recommendation**:
- handle the current event catalog
- handle all four handler types
- reflect `disableAllHooks`
- reflect `allowManagedHooksOnly`
- keep provenance at event and handler granularity

### Packet R3: MCP Resolver Updates

**Goal**: Resolve MCP sources, controls, and managed policy correctly.

**Expanded recommendation**:
- integrate:
  - managed MCP
  - user MCP
  - local/project MCP
  - allow/deny rule evaluation
  - enable/disable lists
  - managed-only gating
- ensure deny rules win where the docs indicate they do

---

## Phase 9: Session UI Updates

### Packet V1: Session Settings View - New Sections

**Goal**: Expand Session Settings to cover the newly supported families.

**Expanded recommendation**:
- organize by user-meaningful sections, not raw key dump
- likely sections:
  - Model
  - Permissions
  - Hooks Policy
  - MCP Policy
  - Sandbox
  - Plugins and Marketplaces
  - Authentication
  - Memory and Instructions
  - UI and Session Experience
  - Worktree
- always show provenance and issues when present

### Packet V2: Session Hooks View - Full Event and Handler Display

**Goal**: Make the hook view reflect the real current hook system.

**Expanded recommendation**:
- show grouped event families
- show matcher details
- show handler-specific details
- show banners for global controls such as `disableAllHooks`

### Packet V3: Session MCP View - Controls and Source Effects

**Goal**: Explain the effective MCP state, not just list servers.

**Expanded recommendation**:
- show why each server is:
  - active
  - disabled
  - blocked
  - managed-only
- surface transport and policy details
- make managed restrictions visible

### Packet V4: Managed Scope View - Full Implementation

**Goal**: Replace the stub Managed scope with a meaningful managed-policy inspector.

**Corrected recommendation**:
- reflect the current managed source tiers:
  - server-managed
  - MDM / OS policy
  - file-based managed settings
- show which tier is active
- show discovered file-based sources and their status
- show managed MCP status
- show access-denied states explicitly
- show managed CLAUDE.md content and status

---

## Phase 10: Validation Hardening

### Packet E4: Schema Validation for All New Keys

**Goal**: Add schema validation that matches the expanded parser surface.

**Expanded recommendation**:
- validate:
  - enum values
  - nested object shapes
  - managed-only scope restrictions
  - hook property compatibility
  - plugin marketplace source shapes
  - MCP restriction rule shapes
- keep validation separate from parsing

### Packet E5: Semantic Validation for New Interactions

**Goal**: Add semantic validation for cross-key and cross-scope interactions.

**Expanded recommendation**:
- cover:
  - ineffective lower-precedence settings masked by managed policy
  - contradictory allow/deny combinations
  - hooks defined but neutralized by `disableAllHooks`
  - malformed or self-conflicting sandbox policies
  - MCP entries blocked by deny rules or managed-only restrictions
  - plugin marketplace policies that make lower-scope values ineffective

---

## Phase 11: Forward Compatibility

### Packet FC1: Dynamic Schema Fetch (Optional)

**Goal**: Explore limited forward compatibility without undermining deterministic local behavior.

**Corrected recommendation**:
- treat this as optional and late
- prefer official sources over third-party ones if a fetch path is implemented
- fetched schema should augment discovery of new keys, not silently replace trusted built-in behavior
- the app must remain fully functional offline

---

## Phase 12: Runtime & Usage Observability (New Track)

This track provides session-level runtime introspection: live session snapshots, transcript discovery, telemetry configuration observability, and prompt/usage views. These packets are independent of the parser/resolver pipeline and can begin once the app shell and discovery foundations are stable.

### Packet T1: Runtime Session Snapshot

**Goal**: Model live session state using the documented status-line JSON schema.

**Deliverables**:
- `StatusLinePayload` and nested types faithfully representing the documented snake_case JSON schema (model as object, cost/context_window/rate_limits as nested objects)
- `RuntimeSessionSnapshot` as a simplified app-facing projection
- best-effort transcript-based session discovery (Claude Code does not write snapshot files to disk)
- `parseStatusLinePayload` method for decoding status-line JSON (enables future integration)

**Acceptance criteria**:
- `StatusLinePayload` decodes the full documented status-line stdin JSON including nested objects
- best-effort transcript-based discovery can identify the most recent session
- stale or absent sessions show explicit "no active session" state
- no references to `current.json` or `status.json` (these files do not exist)

### Packet T2: Transcript Discovery and Browsing

**Goal**: Discover and browse Claude Code session transcripts with best-effort parsing.

**Deliverables**:
- glob-style discovery of transcript files under `~/.claude/projects/`
- best-effort metadata extraction from undocumented JSONL format (session identity from filename stems/path classification, model from first lines)
- classification of primary session transcripts vs subagent transcripts to avoid double-counting
- raw JSON preserved for every line as authoritative representation
- chronological listing of recent transcripts
- basic transcript content viewer with raw JSON toggle

**Acceptance criteria**:
- transcripts are discovered and listed with file metadata
- primary session transcripts and subagent transcripts are classified separately
- users can browse recent session transcripts
- unknown record types and unexpected fields are preserved, not rejected
- missing or corrupt transcript files produce attributable issues, not crashes

### Packet T3: Telemetry / OTel Configuration Display (Optional)

**Goal**: Detect and display OpenTelemetry configuration and privacy/correlation state (detection/display only, no data ingestion).

**Deliverables**:
- detection of OTel configuration from env vars in settings and `otelHeadersHelper` (string script path, not object)
- display of OTel configuration state: enabled, exporters, endpoints, per-signal protocols, privacy flags, and headers-helper timing
- reference list of Claude Code metric names, event names, and prompt-level correlation attributes (compiled from docs)
- validation for common misconfigurations

**Acceptance criteria**:
- `otelHeadersHelper` is treated as a string (script path), not an object
- no HTTP requests are made to any OTel endpoint (push-only model)
- when OTel is not configured, this section is absent (not errored)
- when configured, display shows exporter types, endpoint/protocol details, and privacy-relevant flags
- secret header values are never displayed in the UI

### Packet T4: Prompt & Usage Views

**Goal**: Provide aggregate usage views from transcript and runtime data.

**Deliverables**:
- per-session usage summary: total tokens, cost, model distribution
- aggregate usage across recent sessions
- prompt history browsing (read-only)
- integration with Session scope view as an optional "Usage" tab

**Acceptance criteria**:
- usage data is computed from local transcripts, never from external APIs
- aggregate views update when new transcripts are discovered
- views handle missing or partial data gracefully

---

## Packet Dependency Graph

```text
G1 -> G2

After G2:
- Managed track: M1 -> M2 -> M3 -> M4
- Permissions/MCP track: P1, P2, P3
- Hooks track: H1 -> H2 -> H3
- Settings family track: S1, S2, S3, S4, J1, U1, U2

After the parser and managed tracks are stable:
- Resolver track: R1, R2, R3

After resolver track:
- Session UI track: V1, V2, V3, V4

After parser/resolver stabilization:
- Validation track: E4, E5

After app shell and discovery foundations:
- Runtime track: T1, T2, T3 (can proceed in parallel); T4 depends on T1 + T2

Optional final track:
- FC1
```

## Summary: 31 Packets across 12 Phases (potentially 32 if S3 is split)

| Phase | Packets | Focus | Priority | Key count |
|-------|---------|-------|----------|-----------|
| 1 | G1, G2 | Schema-driven parser foundation | Foundation | N/A (infrastructure) |
| 2 | M1, M2, M3, M4 | Managed settings tier | Critical | 3 discovery paths + MDM |
| 3 | P1, P2, P3 | Permissions and MCP controls | Critical | 13 keys |
| 4 | H1, H2, H3 | Modern hook system | Critical | 25 events, 4 handler types, 10+ properties |
| 5 | S1, S2, S3(/S3b), S4 | Model, auth, sandbox, plugins | High | 9 + 5 + 21 + 7 = 42 keys |
| 6 | J1 | ~/.claude.json completion | High | 6 verified global config keys |
| 7 | U1, U2 | UI/UX, worktree, remaining verified keys | Medium | 14 + 9 = 23 keys |
| 8 | R1, R2, R3 | Resolver integration | High | N/A (wiring) |
| 9 | V1, V2, V3, V4 | Session and Managed UI | High | N/A (presentation) |
| 10 | E4, E5 | Validation hardening | Medium | N/A (cross-cutting) |
| 11 | FC1 | Forward compatibility | Optional | N/A |
| 12 | T1, T2, T3, T4 | Runtime & usage observability | Optional | Session runtime + transcripts |

**Total new settings keys to be modeled**: ~84 keys across settings.json + 6 keys in ~/.claude.json + 25 hook events + 4 handler types

## Estimated effort

The packet count remains similar (27, potentially 28 if S3 is split), but the expected scope has shifted:

- the highest risk packets are now `M3`, `H1`, `H2`, `H3`, `S3`, `S4`, `R1`, `R2`, and `R3`
- `S3` (Sandbox) is the single largest packet by key count (21 keys across nested objects) and is a candidate for splitting into S3a/S3b
- `H3` has grown significantly with the addition of `once`, `shell`, `model`, `headers`, and the `timeoutMs` → `timeout` migration
- the most outdated local assumptions were in managed resolution, hooks, MCP restrictions, sandbox configuration, and plugin marketplace policy
- the March 31 2026 comprehensive review added 17 previously untracked settings keys and 1 critical data model correction (`timeoutMs` → `timeout`)
- finishing the critical trust path means completing:
  - Phase 1
  - Phase 2
  - Phase 3
  - Phase 4
  - enough of Phase 5 and Phase 8 to make Session trustworthy

## Working convention reminder

For each packet session:

1. Load `PROJECT_INDEX.md`
2. Load the relevant section doc
3. Load this plan
4. Load any relevant handoff docs
5. Read the exact source files and tests being changed
6. Implement and test
7. Produce a handoff doc named `<PACKET_ID>-handoff.md`

## Verification sources used for this revision

- current project docs in `Documents/`
- current source under `ClaudeConfigManager/`
- Claude Code settings docs
- Claude Code hooks docs
- Claude Code IAM / managed settings docs
- Claude Code server-managed settings docs
- SchemaStore Claude Code settings schema used as a supplemental cross-check, not the sole source of truth

### March 31 2026 Comprehensive Review addendum

Additional verification performed against:
- Official Claude Code settings documentation at `https://code.claude.com/docs/en/settings` (fetched March 31 2026)
- Official Claude Code hooks reference at `https://code.claude.com/docs/en/hooks` (fetched March 31 2026)
- Full source code review of all parsers, models, resolver, discovery, and view files in the current codebase
- Cross-referencing of every settings.json key in official docs against current parser coverage
- Cross-referencing of every hook event, handler type, and property against current hook model
- Results documented in `Documents/COMPREHENSIVE_REVIEW.md`

**Key corrections from this review:**
1. `timeoutMs` in `ParsedHookAction` must become `timeout` (seconds) — the official docs use seconds, not milliseconds
2. 17 previously untracked settings keys identified and assigned to packets
3. 6 ~/.claude.json-only global config keys identified and assigned to J1
4. Sandbox packet S3 expanded from general guidance to full 21-key inventory
5. Attribution model expanded from `includeCoAuthoredBy` to `attribution.commit` + `attribution.pr`
6. Hook handler properties expanded with `once`, `shell`, `model`, `headers`

# Claude Config Manager — Comprehensive Review

## Review Date: March 31, 2026
## Scope: Current implementation vs. official Claude Code docs vs. implementation plan

---

## 1. Executive Summary

The Claude Config Manager is a well-architected macOS SwiftUI app with strong foundations in its parser layer, discovery system, and resolution models. However, there is a **significant gap** between what the app currently parses and what Claude Code's configuration surface actually contains. The implementation plan (V2, 27 packets across 11 phases) correctly identifies most of these gaps, but there are still some discrepancies between the plan's understanding and the current official documentation.

**Key findings:**
- The current parsers cover roughly **30-40%** of the actual settings.json surface
- The hook system models only the basic structure; 25 event types, 4 handler types, and many properties are missing
- Permissions, sandbox, MCP controls, and plugin/marketplace settings are absent or skeletal
- The implementation plan is mostly accurate but has some drift from current docs
- The resolver and validation layers have solid architecture but lack the data to be meaningful yet
- The UI layer (SessionScopeView) has good infrastructure but is displaying a small fraction of the eventual data

---

## 2. Settings.json — Field Coverage Comparison

### 2.1 Currently Parsed by SettingsParser.swift

| Key | Parsed? | Notes |
|-----|---------|-------|
| `$schema` | Yes | Recognized and preserved |
| `apiKeyHelper` | Yes | String |
| `autoMemoryDirectory` | Yes | String |
| `cleanupPeriodDays` | Yes | Integer |
| `companyAnnouncements` | Yes | String array |
| `env` | Yes | String map via ParsedEnvMap |
| `attribution` | Partial | Only `includeCoAuthoredBy` parsed; `commit` and `pr` sub-keys not modeled |
| `includeCoAuthoredBy` | Yes | Deprecated key, still parsed |
| `includeGitInstructions` | Yes | Boolean |
| `permissions` | Partial | Only `allow` and `deny` arrays; missing `ask`, `defaultMode`, `additionalDirectories`, `disableBypassPermissionsMode` |
| `autoMode` | Yes | Recognized as key |
| `disableAutoMode` | Yes | Recognized |
| `useAutoModeDuringPlan` | Yes | Recognized |
| `disableDeepLinkRegistration` | Yes | Recognized |
| `hooks` | Partial | Basic event/matcher/action structure only; see Hook section |
| `allowManagedHooksOnly` | Yes | Boolean |
| `allowedHttpHookUrls` | Yes | String array (JSON key is `allowedHttpHookUrls`; Swift property uses `allowedHTTPHookURLs` per Swift naming conventions — this is correct) |
| `httpHookAllowedEnvVars` | Yes | String array |
| `plugins` | Yes | Recognized as key |

### 2.2 Missing from SettingsParser (per official docs, March 2026)

**Model & AI Behavior:**
- `model` — string (model ID override)
- `availableModels` — string array
- `modelOverrides` — object (model ID mapping)
- `effortLevel` — enum: "low", "medium", "high"
- `alwaysThinkingEnabled` — boolean
- `fastModePerSessionOptIn` — boolean
- `feedbackSurveyRate` — number (0-1)

**Authentication & Identity:**
- `forceLoginMethod` — enum: "claudeai", "console"
- `forceLoginOrgUUID` — UUID string
- `otelHeadersHelper` — string (script path)
- `awsAuthRefresh` — string (script)
- `awsCredentialExport` — string (script)

**Sandbox Configuration (entire `sandbox` object):**
- `sandbox.enabled` — boolean
- `sandbox.failIfUnavailable` — boolean
- `sandbox.autoAllowBashIfSandboxed` — boolean
- `sandbox.excludedCommands` — string array
- `sandbox.allowUnsandboxedCommands` — boolean
- `sandbox.filesystem.allowWrite` — string array
- `sandbox.filesystem.denyWrite` — string array
- `sandbox.filesystem.denyRead` — string array
- `sandbox.filesystem.allowRead` — string array
- `sandbox.filesystem.allowManagedReadPathsOnly` — boolean (managed only)
- `sandbox.network.allowUnixSockets` — string array
- `sandbox.network.allowAllUnixSockets` — boolean
- `sandbox.network.allowLocalBinding` — boolean
- `sandbox.network.allowedDomains` — string array
- `sandbox.network.allowManagedDomainsOnly` — boolean (managed only)
- `sandbox.network.httpProxyPort` — number
- `sandbox.network.socksProxyPort` — number
- `sandbox.enableWeakerNestedSandbox` — boolean
- `sandbox.enableWeakerNetworkIsolation` — boolean

**MCP Control Settings:**
- `allowManagedMcpServersOnly` — boolean (managed only)
- `enableAllProjectMcpServers` — boolean
- `enabledMcpjsonServers` — string array
- `disabledMcpjsonServers` — string array
- `allowedMcpServers` — typed rule object array (managed)
- `deniedMcpServers` — typed rule object array (managed)

**Plugin & Marketplace Control:**
- `enabledPlugins` — object (plugin-name@marketplace: boolean)
- `extraKnownMarketplaces` — object (marketplace definitions)
- `strictKnownMarketplaces` — structured array (managed only)
- `blockedMarketplaces` — structured array (managed only)
- `pluginTrustMessage` — string (managed only)
- `channelsEnabled` — boolean (managed only)
- `allowedChannelPlugins` — object array (managed only)

**Permission Fields Missing:**
- `permissions.ask` — string array (new)
- `permissions.defaultMode` — enum
- `permissions.additionalDirectories` — string array
- `permissions.disableBypassPermissionsMode` — string ("disable")
- `allowManagedPermissionRulesOnly` — boolean (managed only, top-level)

**UI & Session Experience:**
- `statusLine` — object (type + command/url)
- `fileSuggestion` — object (type + command)
- `language` — string
- `respectGitignore` — boolean
- `outputStyle` — string
- `defaultShell` — enum: "bash", "powershell"
- `prefersReducedMotion` — boolean
- `spinnerVerbs` — object (mode + verbs array)
- `spinnerTipsEnabled` — boolean
- `spinnerTipsOverride` — object (excludeDefault + tips)
- `voiceEnabled` — boolean
- `agent` — string (named subagent)
- `showClearContextOnPlanAccept` — boolean

**Attribution (expanded):**
- `attribution.commit` — string
- `attribution.pr` — string

**Worktree:**
- `worktree.sparsePaths` — string array
- `worktree.symlinkDirectories` — string array (NEW — not in implementation plan)

**Updates:**
- `autoUpdatesChannel` — enum: "stable", "latest"
- `plansDirectory` — string
- `disableAllHooks` — boolean (already partially handled)

### 2.3 Key Casing Note

The JSON key `allowedHttpHookUrls` is correctly used in parsing (line 246 of SettingsParser.swift). The Swift property `allowedHTTPHookURLs` follows Swift naming conventions for acronyms. This is correct behavior — no discrepancy.

---

## 3. Hook System — Coverage Comparison

### 3.1 Current Hook Model in SettingsParser

The current parser models hooks as:
- `ParsedHooks` containing a dictionary of event name → array of matcher groups
- Each matcher group has a `matcher` string and array of `ParsedHookAction`
- `ParsedHookAction` has: `type`, `command`, `url`, `timeoutMs`

### 3.2 What's Missing (per official docs)

**Hook Events (25 total, none currently enumerated):**

| Event | Supports Matchers | Can Block | Status |
|-------|-------------------|-----------|--------|
| SessionStart | Yes (startup, resume, clear, compact) | No | Not modeled |
| SessionEnd | Yes (clear, resume, logout, etc.) | No | Not modeled |
| UserPromptSubmit | No | Yes | Not modeled |
| PreToolUse | Yes (tool name regex) | Yes | Not modeled |
| PostToolUse | Yes (tool name regex) | Yes | Not modeled |
| PostToolUseFailure | Yes (tool name regex) | No | Not modeled |
| PermissionRequest | Yes (tool name) | Yes | Not modeled |
| Notification | Yes (type) | No | Not modeled |
| Stop | No | Yes | Not modeled |
| StopFailure | Yes (error type) | No | Not modeled |
| SubagentStart | Yes (agent type) | No | Not modeled |
| SubagentStop | Yes (agent type) | Yes | Not modeled |
| PreCompact | Yes (manual, auto) | No | Not modeled |
| PostCompact | Yes (manual, auto) | No | Not modeled |
| InstructionsLoaded | Yes (trigger type) | No | Not modeled |
| ConfigChange | Yes (config type) | Yes | Not modeled |
| WorktreeCreate | No | Yes | Not modeled |
| WorktreeRemove | No | No | Not modeled |
| Elicitation | Yes (MCP server name) | Yes | Not modeled |
| ElicitationResult | Yes (MCP server name) | Yes | Not modeled |
| CwdChanged | No | No | Not modeled |
| FileChanged | Yes (filename) | No | Not modeled |
| TaskCreated | No | Yes | Not modeled |
| TaskCompleted | No | Yes | Not modeled |
| TeammateIdle | No | Yes | Not modeled |

**Hook Handler Types (4 total):**

| Type | Key Properties | Current Status |
|------|----------------|----------------|
| `command` | command, shell, async | Partially modeled (command only) |
| `http` | url, headers, allowedEnvVars | Partially modeled (url only) |
| `prompt` | prompt, model | Not modeled |
| `agent` | prompt, model | Not modeled |

**Common Hook Properties Missing:**
- `if` — permission rule syntax filter
- `timeout` — seconds (not `timeoutMs`)
- `statusMessage` — custom spinner message
- `once` — boolean (skills only)
- `shell` — "bash" or "powershell"
- `async` — boolean
- `headers` — object (for http type)
- `allowedEnvVars` — string array (for http type)
- `model` — string (for prompt/agent types)

**Important note:** The current parser uses `timeoutMs` but official docs use `timeout` in seconds. This is a potential data model mismatch.

---

## 4. ~/.claude.json — Coverage Comparison

### 4.1 Currently Parsed by ClaudeJsonParser

- `$schema` — recognized
- `globalPreferences.defaultModel` — string
- `globalPreferences.defaultMode` — string
- `globalPreferences.telemetryEnabled` — boolean
- `mcp.user.*` and `mcp.local.*` — MCP server definitions
- `trust.trustedProjectPaths` — string array
- `trust.blockedProjectPaths` — string array

### 4.2 What the Docs Say Lives in ~/.claude.json

Per the official docs, `~/.claude.json` contains:
- User preferences (theme, notification settings, editor mode)
- OAuth session data
- MCP server configurations (user and local scopes)
- Per-project state (allowed tools, trust settings)
- Various caches

**Global config settings (stored in ~/.claude.json, NOT settings.json):**
- `autoConnectIde` — boolean
- `autoInstallIdeExtension` — boolean
- `editorMode` — "normal" or "vim"
- `showTurnDuration` — boolean
- `terminalProgressBarEnabled` — boolean
- `teammateMode` — "auto", "in-process", or "tmux"

### 4.3 Gap Assessment

The current parser is missing the ~/.claude.json-specific global config keys (`autoConnectIde`, `autoInstallIdeExtension`, `editorMode`, `showTurnDuration`, `terminalProgressBarEnabled`, `teammateMode`). The implementation plan's Packet J1 addresses this but needs updating to include `teammateMode` which appears to be new.

---

## 5. MCP Configuration — Coverage Comparison

### 5.1 Current MCP Parsing

The ClaudeJsonParser handles MCP servers within `~/.claude.json` under `mcp.user` and `mcp.local` with fields: `command`, `args`, `env`, `url`, `headers`, `enabled`, `source`.

The WorkspaceScanner discovers `.mcp.json` files. There appears to be an McpJsonParser based on test files.

### 5.2 What's Missing

**MCP Control Settings (in settings.json):**
- `allowManagedMcpServersOnly` — not parsed
- `enableAllProjectMcpServers` — not parsed
- `enabledMcpjsonServers` / `disabledMcpjsonServers` — not parsed
- `allowedMcpServers` / `deniedMcpServers` typed rule objects — not parsed

**Managed MCP:**
- `managed-mcp.json` at `/Library/Application Support/ClaudeCode/` — not discovered
- Managed MCP server definitions with enforcement rules — not modeled

**MCP Server Transport Normalization:**
The docs describe two transport types: stdio (command-based) and remote (URL-based). The current parser handles both at a basic level but doesn't normalize or classify them.

---

## 6. Managed Settings — Coverage Comparison

### 6.1 Current State

The WorkspaceScanner and RootLocator are focused on user (`~/.claude/`) and project (`.claude/`) scopes. There is a `ManagedScopeView.swift` but it's a 46-line placeholder.

### 6.2 What's Needed (per docs)

**Discovery paths (macOS):**
- `/Library/Application Support/ClaudeCode/managed-settings.json`
- `/Library/Application Support/ClaudeCode/managed-settings.d/*.json` (drop-in directory)
- `/Library/Application Support/ClaudeCode/managed-mcp.json`
- macOS MDM plist domain: `com.anthropic.claudecode`

**Precedence within managed tier (critical — the plan gets this right):**
1. Server-managed settings (from Anthropic servers)
2. MDM/OS-level policies (plist on macOS)
3. File-based (managed-settings.json + managed-settings.d/)

Only the file-based tier merges internally. Tiers are mutually exclusive (highest present wins).

**Merge behavior for file-based tier:**
- `managed-settings.json` merged first as base
- `managed-settings.d/*.json` sorted alphabetically, merged on top
- Scalars: later overrides earlier
- Arrays: concatenated and deduplicated
- Objects: deep-merged
- Hidden files (`.` prefix) ignored

### 6.3 Plan vs. Docs Assessment

The implementation plan (Packets M1-M4) correctly identifies:
- File-based discovery paths
- MDM plist reading
- Precedence tiers
- Sandbox entitlement requirements

**Minor discrepancy:** The plan mentions the Windows registry path but for a macOS-only app this is irrelevant. The plan should note that `server-managed` settings are fetched remotely and may not be readable locally, so the app would need to acknowledge this tier exists but may not be able to inspect it.

---

## 7. Agent & Skill Parsers — Assessment

### 7.1 Agent Parser

The AgentParser handles YAML frontmatter with fields: `name`, `description`, `tools` (string array). This aligns with the docs which describe agent files as markdown with YAML frontmatter defining name, description, and tool restrictions.

**Assessment:** Adequate for current needs. The `tools` field is the key configuration element. Unknown fields are preserved for forward compatibility.

### 7.2 Skill Parser

The SkillParser handles SKILL.md files with frontmatter fields: `name`, `description`, `version`, `tags`. It also extracts markdown references (links/images) from the body.

**Assessment:** Reasonable coverage. Skills may have additional frontmatter fields in practice (e.g., `license`, triggers, auto-load conditions) that aren't enumerated in the parser's known fields, but forward compatibility via `unknownFields` handles this.

---

## 8. Scope Precedence Model — Assessment

### 8.1 Current Model

The `ResolutionScope` enum defines: managed, user, project, projectLocal, session, cli, imported, autoMemory, synthetic.

### 8.2 Official Precedence (per docs)

1. **Managed** (highest — cannot be overridden)
2. **Command line arguments**
3. **Local** (`.claude/settings.local.json`)
4. **Project** (`.claude/settings.json`)
5. **User** (`~/.claude/settings.json`)

**Array settings merge across scopes** (concatenated + deduplicated), not replaced.

### 8.3 Assessment

The current model's scope enum is comprehensive and includes the right tiers. The critical detail is array merge behavior — the current `MergeMethod` enum includes `append`, `appendUnique`, `setUnion` which can represent this. The implementation needs to ensure each key's merge method is correctly assigned.

**Important nuance from docs:** "Managed" can't be overridden "including command line arguments." This means managed > CLI, which the plan correctly models.

---

## 9. Implementation Plan vs. Current Docs — Discrepancies

### 9.1 Keys the Plan Misses

| Key | In Docs | In Plan | Notes |
|-----|---------|---------|-------|
| `worktree.symlinkDirectories` | Yes | No | New setting for symlinked directories in worktrees |
| `voiceEnabled` | Yes | No | Voice dictation toggle |
| `defaultShell` | Yes | No (not in key listings) | "bash" or "powershell" |
| `showClearContextOnPlanAccept` | Yes | No | Boolean for plan accept screen |
| `agent` | Yes | No | Named subagent for main thread |
| `teammateMode` | Yes (in ~/.claude.json) | No | Agent team display mode |
| `sandbox.failIfUnavailable` | Yes | Unclear | Hard gate for sandbox requirement |
| `sandbox.allowUnsandboxedCommands` | Yes | Unclear | Escape hatch control |
| `sandbox.network.httpProxyPort` | Yes | Unclear | Custom proxy port |
| `sandbox.network.socksProxyPort` | Yes | Unclear | SOCKS5 proxy port |
| `sandbox.enableWeakerNetworkIsolation` | Yes | Unclear | macOS TLS trust service access |

### 9.2 Naming Discrepancies

| Plan Name | Docs Name | Issue |
|-----------|-----------|-------|
| ~~`allowedHTTPHookURLs`~~ | `allowedHttpHookUrls` | Actually correct — Swift property naming vs JSON key. No real issue. |
| Hook `timeoutMs` | Hook `timeout` (seconds) | Unit mismatch — docs use seconds |

### 9.3 Structural Differences

**Attribution:** The plan models `attribution.includeCoAuthoredBy` but the docs show `attribution` as an object with `commit` and `pr` string fields, with `includeCoAuthoredBy` being a separate deprecated top-level key.

**Hook `once` property:** The docs mention a `once` boolean property for hooks (skills only). This doesn't appear in the plan's H2/H3 packets.

**Hook `shell` property:** Command hooks support a `shell` property ("bash" or "powershell"). Not clearly in the plan.

---

## 10. Architecture & Code Quality Assessment

### 10.1 Strengths

1. **Protocol-based dependency injection** — `WorkspaceScanningFileSystem`, `BookmarkDataCoding`, `RootBookmarkResolving` enable clean testing
2. **Comprehensive error model** — `SyntaxIssue`, `ValidationIssue`, `ResolutionIssue`, `DiscoveryIssue` provide layered error tracking with severity, codes, and source provenance
3. **Forward compatibility** — All parsers preserve unknown fields in `rawObject`/`unknownFields` dictionaries
4. **Fixture-based testing** — Deterministic test data with expected outputs, well-organized by parser/case
5. **Bookmark management** — Proper macOS sandbox handling with security-scoped bookmarks, staleness detection, and reauthorization flows
6. **Resolver models** — Well-thought-out `MergeMethod` enum and `ResolutionTrace` for provenance tracking

### 10.2 Concerns

1. **Custom YAML parser** — The AgentParser and SkillParser use a hand-rolled YAML parser that doesn't support the full YAML spec. While adequate for simple frontmatter, edge cases (multiline strings, anchors, tags) could cause issues with real-world agent files. Consider using a proper YAML library or documenting limitations.

2. **Parser duplication** — The YAML parsing logic appears duplicated between AgentParser and SkillParser. This should be extracted into a shared `FrontmatterParser` utility.

3. **Settings key discovery is bespoke** — The current SettingsParser hard-codes known keys. The implementation plan (G1/G2) correctly identifies that this should be registry-driven, but until those packets land, adding new keys requires modifying the parser.

4. **No managed settings discovery** — The WorkspaceScanner only looks in user and project roots. Managed paths (`/Library/Application Support/ClaudeCode/`) are not scanned.

5. **Hook model is too simple** — The current `ParsedHookAction` only has `type`, `command`, `url`, `timeoutMs`. It needs to be significantly expanded to cover all handler types and their properties.

6. **No sandbox parsing at all** — The entire `sandbox` nested object family is unhandled. This is a large surface area.

---

## 11. Comparison: Plan Packet Ordering vs. What Matters Most

### 11.1 Plan's Critical Path

The plan identifies: Phases 1-4 + enough of Phase 5 and Phase 8 as the critical path to "trustworthy."

### 11.2 My Assessment of Priority

**Highest impact (trust & correctness):**
1. **G1/G2** (Schema registry) — Foundation for everything else. Correct priority.
2. **P1** (Modern permissions) — `ask`, `defaultMode`, `additionalDirectories` are actively used. Critical.
3. **H1/H2** (Hook events and handlers) — Users configuring hooks need to see them correctly. Critical.
4. **S3** (Sandbox) — Large surface area, actively used in enterprise. High priority.
5. **M1-M3** (Managed settings) — Enterprise users need this. Correctly prioritized.

**Medium impact (completeness):**
6. **S1** (Model settings) — Commonly configured, visible in daily use
7. **P2/P3** (MCP controls) — Important for managed environments
8. **S4** (Plugins) — Growing in importance
9. **U1/U2** (UI settings) — Many keys, but mostly simple scalars

**Lower impact (polish):**
10. **R1-R3** (Resolver integration) — Depends on parser completeness
11. **V1-V4** (Session UI) — Depends on resolver
12. **E4/E5** (Validation) — Polish layer
13. **FC1** (Dynamic schema) — Nice-to-have

### 11.3 Recommendation

The plan's ordering is sound. The main risk is that the **plan underestimates the sandbox surface area** (Packet S3). The official docs list 19 sandbox-related keys across nested objects. This packet may need to be split or given more time.

---

## 12. Summary of Gaps (Ordered by Severity)

### Critical Gaps (affect correctness of displayed configuration)

1. **Permissions model incomplete** — missing `ask`, `defaultMode`, `additionalDirectories`, `disableBypassPermissionsMode`
2. **Hook handler types** — only `command` and `http` partially modeled; `prompt` and `agent` types absent
3. **Hook properties** — `if`, `timeout` (not `timeoutMs`), `statusMessage`, `once`, `shell`, `async`, `headers`, `allowedEnvVars`, `model` all missing
4. **Sandbox configuration** — entire nested object family unhandled (19+ keys)
5. **MCP control settings** — 6 control keys not parsed
6. **Managed settings discovery** — not implemented at all

### Significant Gaps (affect completeness)

7. **Model/AI behavior settings** — 7 keys missing
8. **Authentication settings** — 5 keys missing
9. **Plugin/marketplace settings** — 7+ keys missing
10. **UI/session experience settings** — 12+ keys missing
11. **Worktree settings** — 2 keys missing
12. **~/.claude.json global config keys** — 6 keys missing
13. **Attribution expanded model** — `commit` and `pr` sub-keys not parsed

### Minor Gaps (cosmetic or edge-case)

14. ~~**Key casing**~~ — Verified correct: Swift property naming convention, JSON key matches docs
15. **Timeout units** — `timeoutMs` vs `timeout` (seconds)
16. **YAML parser limitations** — custom parser may fail on complex frontmatter
17. **Missing keys from plan** — `worktree.symlinkDirectories`, `voiceEnabled`, `defaultShell`, `showClearContextOnPlanAccept`, `agent`, `teammateMode`

---

## 13. Recommendations

1. **Prioritize G1/G2** — The schema registry is the single most impactful change. Once it exists, adding new keys becomes mechanical.

2. **Update the plan** to include newly documented keys: `worktree.symlinkDirectories`, `voiceEnabled`, `defaultShell`, `showClearContextOnPlanAccept`, `agent`, `teammateMode`, and any sandbox keys not yet enumerated.

3. **Verify JSON schema** at `https://json.schemastore.org/claude-code-settings.json` periodically to catch newly added keys.

4. **Fix the timeout unit** from `timeoutMs` to `timeout` (seconds) to match the official hook specification.

5. **Consider splitting Packet S3** (Sandbox) given the 19+ keys across nested filesystem and network objects.

6. **Extract shared YAML parsing** from AgentParser and SkillParser into a common utility to reduce duplication and centralize bug fixes.

7. **Add a "coverage dashboard"** — a simple view or report showing what percentage of the official settings surface the app currently handles, to track progress across packets.

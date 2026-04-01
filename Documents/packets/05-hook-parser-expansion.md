# Packet 05 — Hook Parser Correction and Expansion

## Context

The current hook parser has a known correctness bug (`timeout` is stored in milliseconds but the Claude Code specification uses seconds) and is missing several properties that are documented and actively used in hook configurations: `once`, `shell`, and handler types `http`, `prompt`, and `agent`. This packet fixes the bug, adds the missing properties, and updates the attribution parsing while it is open.

**Prerequisite: Packets 01 and 03 must be complete.**

## Prerequisites

- Packet 01 complete (pipeline wiring fixed)
- Packet 03 complete (key registry exists; hook keys should already be registered there)

## Deliverables

### 1. Read the existing hook parser

Before making any changes, read `ClaudeConfigManager/Infrastructure/Parsers/` and find the hook-related parsing code. It may be inside `SettingsParser.swift` or a dedicated `HookParser.swift`. Understand the current `HookHandler` or equivalent model type.

### 2. Fix `timeout` units

The `timeout` property on hook handlers must be stored and displayed in **seconds** (an integer or floating-point value as specified in the Claude Code documentation). If the current code divides or multiplies by 1000, remove that conversion. If the current UI displays "ms" labels, change them to "s".

Update any existing hook fixture files that contain timeout values to use second-scale values (e.g. `30` not `30000`).

### 3. Add `once` property

Add `once: Bool?` to the hook handler model. This property is only meaningful for hooks attached to skills and indicates the handler fires at most once per session. Parse it from the JSON `once` key. Default: nil (absent = false semantics).

### 4. Add `shell` property

Add `shell: String?` to the hook handler model. Valid values: `"bash"`, `"powershell"`. Parse from the JSON `shell` key. Emit a `.invalidEnumValue` issue (using the registry pattern from Packet 03) if a value other than those two is found.

### 5. Add new handler types

The current parser likely supports only `command`-type handlers. Extend the handler type enum and model to support:

**`http` handler** — additional fields:
- `url: String` (required)
- `method: String?` — e.g. `"POST"`, `"GET"` (optional, default POST)
- `headers: [String: String]?` (optional)
- `body: String?` (optional, treated as a template string)

**`prompt` handler** — additional fields:
- `template: String` (required)
- `model: String?` (optional, defaults to session model)

**`agent` handler** — additional fields:
- `agentId: String` (required — key is `agent_id` in JSON)
- `inputs: [String: JSONValue]?` (optional)

For each new handler type, parse all fields and emit `.missingRequiredField(key)` if a required field is absent.

### 6. Fix attribution parsing

Locate where `attribution` / `includeCoAuthoredBy` is parsed (likely in `SettingsParser` or a dedicated parser). Update it so that:
- `attribution` is parsed as an object with `commit: String?` and `pr: String?` sub-keys
- `includeCoAuthoredBy: Bool?` remains parseable for backward compatibility
- When `includeCoAuthoredBy` is found, emit an info-level `.deprecatedKey("includeCoAuthoredBy", "Use attribution.commit and attribution.pr instead")` issue

### 7. Update fixture files

- Add fixture cases in `ClaudeConfigManagerTests/Fixtures/` for:
  - A hook with `timeout` in seconds, `once: true`, `shell: "bash"`
  - An `http`-type handler with all fields
  - A `prompt`-type handler
  - An `agent`-type handler
  - A settings file using the new `attribution` object format
  - A settings file using the deprecated `includeCoAuthoredBy` (must parse without error, plus deprecation issue)

### 8. Update tests

Update all existing hook-related tests that may use old millisecond timeout values.

Create new tests for:
- Each new handler type (http, prompt, agent) — parsing valid and invalid fixtures
- `once` and `shell` properties
- `attribution` object format
- Deprecated `includeCoAuthoredBy` emitting the deprecation issue

## Build and Test

```bash
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager \
  -destination 'platform=macOS' -quiet 2>&1 | tail -30
```

**Done criteria:**
- All new hook parser tests pass
- All existing tests pass (none broken by the timeout unit change)
- Build has zero warnings
- No handler type in the codebase is named or documented as accepting "milliseconds" for timeout

## Handover Note

Only create `Documents/05-handoff.md` if work deviated from the plan. Record what was completed, what was not, any unexpected shape in the existing hook model, and recommended next step.

# Packet 03 — Settings Key Registry

## Context

The current settings parser handles keys in an ad-hoc, property-by-property way. This makes it brittle when Anthropic adds new keys (a code change is required for each one) and means validation, scope restrictions, and merge hints are scattered rather than centralised. This packet builds a schema-driven `SettingsKeyRegistry` that will become the single source of truth for everything the app knows about settings keys. Every parser, validator, editor, and scope recommendation feature downstream depends on this registry.

**Prerequisite: Packet 01 must be complete.**

## Prerequisites

- Packet 01 complete (build green, all tests passing)

## Deliverables

### 1. `SettingsKeyDefinition.swift`

Create `ClaudeConfigManager/Infrastructure/Parsers/SettingsKeyDefinition.swift`.

```swift
struct SettingsKeyDefinition {
    let keyPath: String            // dot-notation path, e.g. "permissions.deny"
    let expectedType: KeyValueType // see enum below
    let scopeRestriction: ScopeRestriction
    let mergeHint: MergeHint
    let isManagedOnly: Bool        // if true, only valid at managed scope
    let isDeprecated: Bool
    let deprecationNote: String?   // plain-English replacement note
    let description: String        // one sentence for UI display
}

enum KeyValueType {
    case string
    case bool
    case int
    case double
    case stringArray
    case objectArray
    case stringDictionary
    case nestedObject(childKeys: [SettingsKeyDefinition])
    case enumString(validValues: [String])
}

enum ScopeRestriction {
    case any                          // valid at any scope
    case managedOnly                  // only meaningful at managed scope
    case notAtManaged                 // personal preference, not for managed deployment
}

enum MergeHint {
    case override                     // highest scope wins entirely
    case appendUnique                 // all scopes' arrays merged, duplicates removed
    case deepMerge                    // per-key precedence within an object
}
```

### 2. `SettingsKeyRegistry.swift`

Create `ClaudeConfigManager/Infrastructure/Parsers/SettingsKeyRegistry.swift`.

This is a static registry — a list of `SettingsKeyDefinition` values. It must cover every documented Claude Code settings key. Use the categories below as the structure. Add all keys you can verify from the app's existing parser code and from official Claude Code documentation patterns visible in the codebase.

**Required key families to cover:**

**Model selection**
- `model` — string, any scope, override, description: "Default model for all sessions"
- `smallModel` — string, any scope, override
- `largeModel` — string, any scope, override
- `maxTokens` — int, any scope, override
- `temperature` — double, any scope, override (valid range 0.0–1.0)

**Output and UI**
- `outputFormat` — enumString(["text","json","stream-json"]), any scope, override
- `verbose` — bool, any scope, override
- `debug` — bool, any scope, override
- `statusLine` — nestedObject (see below), any scope, deepMerge
- `showTurnDuration` — bool, any scope, override
- `preferredNotifChannel` — enumString(["terminal","...any documented values"]), any scope, override

**Permissions** (all three are stringArray, appendUnique)
- `permissions.allow`
- `permissions.deny`
- `permissions.ask`

**Hooks** — each lifecycle event is an objectArray, appendUnique
- `hooks.PreToolUse`
- `hooks.PostToolUse`
- `hooks.PreCompact`
- `hooks.UserPromptSubmit`
- `hooks.SessionStart`
- `hooks.SessionEnd`
- `hooks.Stop`
- `hooks.SubagentStop`
- `hooks.Notification`

**Sandbox** (all nestedObject children or scalar, managed-or-any depending on security relevance)
- `sandbox.failIfUnavailable` — bool
- `sandbox.allowUnsandboxedCommands` — bool
- `sandbox.network.allowedDomains` — stringArray, appendUnique
- `sandbox.network.httpProxyPort` — int
- `sandbox.network.socksProxyPort` — int
- `sandbox.enableWeakerNetworkIsolation` — bool

**Environment**
- `env` — stringDictionary, deepMerge

**Worktree** — add any worktree-related keys visible in the existing parser
**File suggestion** — `fileSuggestion.*` keys visible in the existing parser
**Plans** — `plansDirectory` — string, any scope, override

**Attribution**
- `attribution` — nestedObject with `commit` (string) and `pr` (string), any scope, override
- `includeCoAuthoredBy` — bool, any scope, override, isDeprecated: true, deprecationNote: "Use attribution.commit and attribution.pr instead"

Read the existing `SettingsParser.swift` to discover any additional keys already being handled. Every key the existing parser handles must have a corresponding registry entry — do not leave any key unregistered.

**Unknown keys:** Any key in a settings file that is NOT in the registry must emit an `.unknownKey(key)` info-level `SyntaxIssue`. This is handled in the parser, not the registry — the registry just defines what is known.

### 3. Registry lookup API

Add these methods to `SettingsKeyRegistry`:

```swift
static func definition(for keyPath: String) -> SettingsKeyDefinition?
static func allKeys() -> [SettingsKeyDefinition]
static func keys(for scope: ResolutionScope) -> [SettingsKeyDefinition]  // filters by scopeRestriction
static func managedOnlyKeys() -> [SettingsKeyDefinition]
```

### 4. Wire into `SettingsParser`

Update `SettingsParser` to use the registry for validation:
- After parsing each key, look it up in the registry
- If not found: emit `.unknownKey(keyPath)` info issue (not a warning or error)
- If found but the value type does not match `expectedType`: emit `.invalidFieldType(keyPath, expected, got)`
- Do not change the parse result shape — `ParseResult<T>` is unchanged

### 5. Unit tests

Create `ClaudeConfigManagerTests/Parsers/SettingsKeyRegistryTests.swift`:
- Test that every key family is present in the registry
- Test `definition(for:)` returns the correct definition for known keys and nil for unknown keys
- Test `keys(for: .managed)` does not return `notAtManaged` keys
- Test that the parser emits an `.unknownKey` issue when given a settings file with an unrecognised key
- Test that the parser emits `.invalidFieldType` when a known key has the wrong JSON type

All existing parser tests must continue to pass.

## Build and Test

```bash
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager \
  -destination 'platform=macOS' -quiet 2>&1 | tail -30
```

**Done criteria:**
- All existing tests pass
- New registry tests pass
- `SettingsParser` emits `.unknownKey` for unknown fields (verified by a new test)
- No hardcoded key name strings remain in `SettingsParser` for keys that are now in the registry

## Handover Note

Only create `Documents/03-handoff.md` if work deviated from the plan. Record what was completed, what was not, any blocking discoveries (e.g. keys in the existing parser that could not be cleanly mapped to the registry), and recommended next step.

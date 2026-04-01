# Packet 04 — Typed Accessor Layer

## Context

Packet 03 built the `SettingsKeyRegistry` — a schema describing every known settings key. This packet builds the **Typed Accessor Layer**: a set of grouped, strongly-typed computed properties that views and resolvers use to read parsed settings without touching raw `JSONValue` dictionaries directly. This makes the code that consumes settings readable, refactor-safe, and self-documenting.

**Prerequisite: Packet 03 must be complete.**

## Prerequisites

- Packets 01 and 03 complete (pipeline wiring fixed, registry built, all tests green)

## Deliverables

### 1. Understand the existing structure

Before writing any code, read:
- `ClaudeConfigManager/Infrastructure/Parsers/SettingsParser.swift` — understand how `SettingsDocument` is currently shaped
- `ClaudeConfigManager/Infrastructure/Resolver/ResolverModels.swift` — understand how settings are consumed by resolvers
- Any existing typed property accessors on `SettingsDocument` (there may be some already)

The goal is to add accessor groupings **on top of** the existing `SettingsDocument` type, not to replace it.

### 2. Accessor group types

Create `ClaudeConfigManager/Infrastructure/Parsers/SettingsAccessors.swift`.

Define the following structs as **lightweight views** over a `SettingsDocument`. They hold a reference to the document and provide computed properties:

```swift
struct ModelSettings {
    let document: SettingsDocument
    var model: String? { ... }
    var smallModel: String? { ... }
    var largeModel: String? { ... }
    var maxTokens: Int? { ... }
    var temperature: Double? { ... }
}

struct PermissionSettings {
    let document: SettingsDocument
    var allowRules: [String] { ... }   // empty array if not set
    var denyRules: [String] { ... }
    var askRules: [String] { ... }
}

struct HookPolicySettings {
    let document: SettingsDocument
    var hooksEnabled: Bool { ... }     // true unless explicitly disabled
    var handlers(for event: HookEvent) -> [JSONValue] { ... }
}

struct MCPPolicySettings {
    let document: SettingsDocument
    var disabledServers: [String] { ... }
    var strictMode: Bool { ... }
}

struct SandboxSettings {
    let document: SettingsDocument
    var failIfUnavailable: Bool? { ... }
    var allowUnsandboxedCommands: Bool? { ... }
    var allowedDomains: [String] { ... }
    var httpProxyPort: Int? { ... }
    var socksProxyPort: Int? { ... }
    var enableWeakerNetworkIsolation: Bool? { ... }
}

struct UISettings {
    let document: SettingsDocument
    var outputFormat: String? { ... }
    var verbose: Bool? { ... }
    var debug: Bool? { ... }
    var showTurnDuration: Bool? { ... }
}

struct WorktreeSettings {
    let document: SettingsDocument
    // add properties for any worktree keys visible in the existing parser
}

struct AttributionSettings {
    let document: SettingsDocument
    var commit: String? { ... }       // from attribution.commit
    var pr: String? { ... }            // from attribution.pr
    var includeCoAuthoredBy: Bool? { ... }  // deprecated, kept for compat
}
```

### 3. Entry points on `SettingsDocument`

Add computed properties to `SettingsDocument` (via extension if needed):

```swift
extension SettingsDocument {
    var modelSettings: ModelSettings { ModelSettings(document: self) }
    var permissionSettings: PermissionSettings { PermissionSettings(document: self) }
    var hookPolicySettings: HookPolicySettings { HookPolicySettings(document: self) }
    var mcpPolicySettings: MCPPolicySettings { MCPPolicySettings(document: self) }
    var sandboxSettings: SandboxSettings { SandboxSettings(document: self) }
    var uiSettings: UISettings { UISettings(document: self) }
    var worktreeSettings: WorktreeSettings { WorktreeSettings(document: self) }
    var attributionSettings: AttributionSettings { AttributionSettings(document: self) }
}
```

### 4. Update call sites

Search the codebase for any place that reads directly from a raw `JSONValue` dictionary on `SettingsDocument` and could instead use the new typed accessors. Update those call sites. Do not change the resolver logic unless the resolver is directly reading raw JSON — in that case, use the accessors.

### 5. Unit tests

Create `ClaudeConfigManagerTests/Parsers/SettingsAccessorTests.swift`:

- For each accessor group, write a test that:
  1. Creates a `SettingsDocument` from a JSON string with the relevant keys
  2. Accesses the typed property
  3. Asserts the value matches

- Test edge cases:
  - Missing key → appropriate default (nil, empty array, or true for `hooksEnabled`)
  - Wrong JSON type for a key → accessor returns nil (not crash)
  - Nested key path (`permissions.deny`) → correctly extracted

All existing parser tests must continue to pass.

## Build and Test

```bash
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager \
  -destination 'platform=macOS' -quiet 2>&1 | tail -30
```

**Done criteria:**
- All new accessor tests pass
- All existing tests (390+) pass
- No raw `JSONValue` dictionary access in call sites that could use the typed accessors
- Build has zero warnings

## Handover Note

Only create `Documents/04-handoff.md` if work deviated from the plan. Record what was completed, what was not, any issues found with the existing `SettingsDocument` structure that prevented clean accessor implementation, and recommended next step.

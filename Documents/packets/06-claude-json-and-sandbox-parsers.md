# Packet 06 — ClaudeJson and Sandbox Parser Expansion

## Context

Two parser gaps remain after Packet 05. The `~/.claude.json` parser (`ClaudeJsonParser`) is missing several documented keys that affect runtime behaviour. The `sandbox` settings family is partially or entirely unimplemented despite governing security-critical behaviour. This packet adds full coverage for both.

**Prerequisite: Packets 01 and 03 must be complete.**

## Prerequisites

- Packet 01 complete (pipeline wiring fixed)
- Packet 03 complete (key registry in place; sandbox keys should already be registered there)

## Deliverables

### Part A — Expand `ClaudeJsonParser`

#### 1. Read the existing parser

Find `ClaudeConfigManager/Infrastructure/Parsers/ClaudeJsonParser.swift`. Read it to understand the current `ClaudeJsonDocument` model and which keys it already handles.

#### 2. Add missing keys to `ClaudeJsonDocument`

Add stored properties (all optional) for each of the following if not already present:

| JSON key | Swift property | Type |
|---|---|---|
| `teammateMode` | `teammateMode` | `Bool?` |
| `autoConnectIde` | `autoConnectIde` | `Bool?` |
| `autoInstallIdeExtension` | `autoInstallIdeExtension` | `Bool?` |
| `editorMode` | `editorMode` | `String?` |
| `showTurnDuration` | `showTurnDuration` | `Bool?` |
| `terminalProgressBarEnabled` | `terminalProgressBarEnabled` | `Bool?` |

Look at the existing parser code for any other keys it handles that are not in this list — ensure those remain handled.

#### 3. Parse the new keys

In the parsing logic, extract each new key from the JSON. Emit `.invalidFieldType(key, expected, got)` if the value is the wrong type. Keys absent from the JSON should leave properties nil — that is not an error.

#### 4. ClaudeJson fixture tests

Add fixture cases at `ClaudeConfigManagerTests/Fixtures/ClaudeJson/`:
- `all_new_keys/input/claude.json` — a file with all six new keys set to valid values
- `all_new_keys/expected/` — expected `ClaudeJsonDocument` output
- `wrong_type/input/claude.json` — a file where one of the new keys has the wrong type
- `wrong_type/expected/` — expected output with an `invalidFieldType` issue

Add tests to the existing `ClaudeJsonParserTests.swift`.

---

### Part B — Sandbox Settings Family

#### 5. Read sandbox-related code

Search the project for any existing `sandbox` parsing code. It may be a stub, partially implemented, or entirely absent. Read what exists before writing anything.

#### 6. `SandboxDocument` model

If a `SandboxDocument` (or equivalent nested type) does not already exist, create it. It should represent the full `sandbox` JSON object:

```swift
struct SandboxDocument {
    var failIfUnavailable: Bool?
    var allowUnsandboxedCommands: Bool?
    var network: SandboxNetworkDocument?
    var enableWeakerNetworkIsolation: Bool?
}

struct SandboxNetworkDocument {
    var allowedDomains: [String]
    var httpProxyPort: Int?
    var socksProxyPort: Int?
}
```

#### 7. Parse sandbox within `SettingsParser`

The `sandbox` key is a nested object within `settings.json`. Parse it within `SettingsParser`:
- If `sandbox` is present but not an object, emit `.invalidFieldType("sandbox", "object", actualType)`
- Parse each sub-key; emit typed field issues for wrong types
- Validate `allowedDomains`: each entry should be a non-empty string; emit `.invalidValue("sandbox.network.allowedDomains", "expected hostname string")` for empty strings
- Validate proxy ports: must be integers in range 1–65535; emit `.invalidValue` for out-of-range values
- Store the parsed `SandboxDocument` on `SettingsDocument`

#### 8. Sandbox fixture tests

Add fixture cases at `ClaudeConfigManagerTests/Fixtures/Settings/`:
- `sandbox_full/input/settings.json` — all sandbox fields set to valid values
- `sandbox_full/expected/` — expected parse result
- `sandbox_invalid_port/input/settings.json` — proxy port out of range
- `sandbox_invalid_port/expected/` — expected parse result with a validation issue
- `sandbox_empty_domain/input/settings.json` — empty string in allowedDomains
- `sandbox_empty_domain/expected/` — expected parse result with a validation issue

Add tests to the existing `SettingsParserTests.swift`.

## Build and Test

```bash
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager \
  -destination 'platform=macOS' -quiet 2>&1 | tail -30
```

**Done criteria:**
- All new parser tests pass
- All existing tests pass
- `SandboxDocument` is accessible from a parsed `SettingsDocument`
- The six new `ClaudeJsonDocument` properties are populated correctly from fixture files
- Build has zero warnings

## Handover Note

Only create `Documents/06-handoff.md` if work deviated from the plan. Record what was completed, what was not, any unexpected structure found in the existing parsers, and recommended next step.

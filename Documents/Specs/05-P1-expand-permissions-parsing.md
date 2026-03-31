# Packet P1: Modern Permissions Parsing

## Overview

This packet expands permissions parsing to match the current Claude Code settings model. The current parser only handles `allow` and `deny`; this adds `ask`, `defaultMode`, `additionalDirectories`, and `disableBypassPermissionsMode`.

## Prerequisites

- G1 and G2 completed (or parseable independently in SettingsParser)

## Pre-read files

- `ClaudeConfigManager/Infrastructure/Parsers/SettingsParser.swift` — current `ParsedPermissions`
- `ClaudeConfigManagerTests/Parsers/SettingsParserTests.swift`
- `Documents/AGENT_FRAMEWORK.md` — Section 11 (Permissions)

## Required fields

### Within `permissions` object

| Key | Type | Description |
|-----|------|-------------|
| `allow` | `[String]?` | Permission rules to allow (already parsed) |
| `deny` | `[String]?` | Permission rules to deny (already parsed) |
| `ask` | `[String]?` | Permission rules requiring confirmation (NEW) |
| `defaultMode` | `String?` | Default permission mode (NEW) |
| `additionalDirectories` | `[String]?` | Additional working directories (NEW) |
| `disableBypassPermissionsMode` | `String?` | Value: `"disable"` to prevent bypass mode (NEW) |

### Top-level key

| Key | Type | Scope | Description |
|-----|------|-------|-------------|
| `allowManagedPermissionRulesOnly` | `Bool` | Managed only | Only managed allow/ask/deny rules apply |

### `defaultMode` valid values

| Value | Description |
|-------|-------------|
| `"default"` | Normal permission prompting |
| `"acceptEdits"` | Accept file edits without prompting |
| `"plan"` | Plan mode |
| `"auto"` | Auto mode (classifier-based) |
| `"dontAsk"` | Don't ask for permissions |
| `"bypassPermissions"` | Bypass all permissions (can be disabled) |
| `"delegate"` | Experimental: delegate permission decisions (schema-only, may not be active) |

**Schema drift tolerance:** The parser should accept ANY string as a `defaultMode` value, not just the known enum values above. Unknown values should produce an info-level issue (not warning or error) to support forward compatibility with experimental modes like `delegate` that may appear in newer Claude Code versions before this app is updated. The known values table is for documentation and UI display purposes only.

**Important:** Do NOT constrain `defaultMode` to only `allow/deny/ask`. The valid values are the permission modes listed above. The `--permission-mode` CLI flag overrides this setting.

## Deliverables

### 1. Updated `ParsedPermissions`

```swift
struct ParsedPermissions {
    let allow: [String]?     // existing
    let deny: [String]?      // existing
    let ask: [String]?       // NEW
    let defaultMode: String? // NEW — permission mode enum
    let additionalDirectories: [String]?     // NEW
    let disableBypassPermissionsMode: String? // NEW — value "disable"
}
```

### 2. Parser updates

- Parse `ask` as string array (same as `allow`/`deny`)
- Parse `defaultMode` as string. Known values are validated for display hints; unknown values are accepted with an info-level issue for forward compatibility.
- Parse `additionalDirectories` as string array
- Parse `disableBypassPermissionsMode` as string, expected value `"disable"`
- Parse top-level `allowManagedPermissionRulesOnly` as boolean
- Non-"disable" `disableBypassPermissionsMode` → warning
- Preserve unknown permission keys for forward compatibility

### 3. Fixtures

**`valid_full_permissions/input/settings.json`:**
```json
{
  "permissions": {
    "allow": ["Bash(npm run lint)", "Read(~/.zshrc)"],
    "deny": ["Bash(curl *)", "Read(./.env)"],
    "ask": ["Bash(git push *)"],
    "defaultMode": "acceptEdits",
    "additionalDirectories": ["../docs/"],
    "disableBypassPermissionsMode": "disable"
  },
  "allowManagedPermissionRulesOnly": true
}
```

**`invalid_permissions/input/settings.json`:**
```json
{
  "permissions": {
    "defaultMode": "yolo",
    "additionalDirectories": "not-an-array",
    "disableBypassPermissionsMode": true
  }
}
```

**`experimental_delegate_mode/input/settings.json`:**
```json
{
  "permissions": {
    "defaultMode": "delegate"
  }
}
```

### 4. Tests

- `ask` array parses alongside `allow` and `deny`
- `defaultMode` with known value parses
- `defaultMode` with unknown value → info-level issue (not warning)
- `defaultMode` with experimental `"delegate"` → parses with info-level issue
- `additionalDirectories` string array parses
- `disableBypassPermissionsMode` with `"disable"` parses
- `disableBypassPermissionsMode` with other string → warning
- `disableBypassPermissionsMode` with boolean → type mismatch
- `allowManagedPermissionRulesOnly` at top level parses
- Existing `allow`/`deny` behavior unchanged

## Acceptance criteria

- [ ] All modern permission fields parse when present
- [ ] `defaultMode` emits info (not warning or error) on unknown values, accepting experimental modes like `delegate`
- [ ] `disableBypassPermissionsMode` handles string vs boolean correctly
- [ ] `allowManagedPermissionRulesOnly` available for resolver
- [ ] Existing `allow`/`deny` behavior unchanged
- [ ] Full test suite passes

# Packet U1: UI, Session Experience, and Git-Oriented Settings

## Overview

This packet adds user-facing settings that shape terminal output, Session ergonomics, and git-adjacent behavior. It also expands the `attribution` model from the deprecated `includeCoAuthoredBy` to the modern `attribution.commit` / `attribution.pr` structure.

## Prerequisites

- G1 and G2 completed (registry and typed accessors)

## Pre-read files

- `ClaudeConfigManager/Infrastructure/Parsers/SettingsParser.swift`
- `ClaudeConfigManagerTests/Parsers/SettingsParserTests.swift`
- `Documents/AGENT_FRAMEWORK.md` — Section 11 (UI & session experience)

## Required settings

### Simple scalar keys

| Key | Type | Description |
|-----|------|-------------|
| `language` | `String?` | Preferred response language (e.g., `"japanese"`) |
| `respectGitignore` | `Bool?` | File picker respects .gitignore (default: true) |
| `outputStyle` | `String?` | Output style name (e.g., `"Explanatory"`) |
| `defaultShell` | `String?` | Enum: `"bash"` (default) or `"powershell"` |
| `voiceEnabled` | `Bool?` | Push-to-talk voice dictation |
| `prefersReducedMotion` | `Bool?` | Reduce UI animations for accessibility |
| `spinnerTipsEnabled` | `Bool?` | Show spinner tips (default: true) |

### Structured object keys

| Key | Type | Description |
|-----|------|-------------|
| `statusLine` | Object | `{ "type": "command", "command": "~/.claude/statusline.sh" }` |
| `fileSuggestion` | Object | `{ "type": "command", "command": "~/.claude/file-suggestion.sh" }` |
| `spinnerVerbs` | Object | `{ "mode": "append"\|"replace", "verbs": ["Pondering"] }` |
| `spinnerTipsOverride` | Object | `{ "excludeDefault": true, "tips": ["Use X"] }` |

### Attribution expansion

| Key | Type | Description |
|-----|------|-------------|
| `attribution.commit` | `String?` | Commit attribution text (empty string hides) |
| `attribution.pr` | `String?` | PR description attribution (empty string hides) |

The deprecated `includeCoAuthoredBy` (already parsed) must remain for backward compatibility. `attribution` takes precedence when both are present.

## Important: scope corrections

`showTurnDuration` and `terminalProgressBarEnabled` are **~/.claude.json keys**, NOT settings.json keys. They are handled in Packet J1. Do NOT add them here.

## Deliverables

### 1. New model types

```swift
struct ParsedStatusLine {
    let type: String?     // "command"
    let command: String?  // script path
    let padding: Int?     // extra horizontal spacing in characters for status line content (default: 0)
    let unknownFields: [String: JSONValue]?
}

struct ParsedFileSuggestion {
    let type: String?     // "command"
    let command: String?  // script path
    let unknownFields: [String: JSONValue]?
}

struct ParsedSpinnerVerbs {
    let mode: String?     // "append" or "replace"
    let verbs: [String]?
    let unknownFields: [String: JSONValue]?
}

struct ParsedSpinnerTipsOverride {
    let excludeDefault: Bool?
    let tips: [String]?
    let unknownFields: [String: JSONValue]?
}

struct ParsedAttribution {
    let commit: String?
    let pr: String?
    let unknownFields: [String: JSONValue]?
}
```

### Status-line runtime data schema (cross-reference)

When `statusLine` is configured as a command, Claude Code pipes a rich snake_case JSON payload to the command's stdin. The full schema is documented in `Documents/Specs/29-T1-runtime-session-snapshot.md` and includes nested objects for `model` (with `id` and `display_name`), `cost`, `context_window`, `rate_limits`, `workspace`, and optional `worktree`/`vim`/`agent` objects.

**Important:** The `model` field in the status-line payload is an object (`{"id": "claude-opus-4-6", "display_name": "Opus"}`), not a plain string. Rate limits use `resets_at` as Unix epoch seconds (Int), not ISO 8601 strings. Rate limits are structured as `five_hour` and `seven_day` windows with `used_percentage` and `resets_at` fields.

This schema is informational for the status-line command's input. The status-line command itself is not parsed by the app — only the settings.json configuration of the status line (type, command, padding) is parsed here. The full `StatusLinePayload` model is defined in T1.

### 2. Parser updates

- Parse all 7 scalar keys with type checking
- Parse 4 structured objects into typed models
- Expand `attribution` parsing: if value is object, parse `commit` and `pr`; if non-object, emit warning
- Validate `defaultShell` as enum: `["bash", "powershell"]`
- Validate `spinnerVerbs.mode` as enum: `["append", "replace"]`
- Preserve unknown fields in all object types

### 3. Fixtures

**`valid_ui_settings/input/settings.json`:**
```json
{
  "language": "japanese",
  "respectGitignore": false,
  "outputStyle": "Explanatory",
  "defaultShell": "bash",
  "voiceEnabled": true,
  "prefersReducedMotion": true,
  "spinnerTipsEnabled": false,
  "statusLine": { "type": "command", "command": "~/.claude/statusline.sh", "padding": 1 },
  "fileSuggestion": { "type": "command", "command": "~/.claude/file-suggestion.sh" },
  "spinnerVerbs": { "mode": "append", "verbs": ["Pondering", "Crafting"] },
  "spinnerTipsOverride": { "excludeDefault": true, "tips": ["Use our internal tool X"] },
  "attribution": { "commit": "Generated with AI\n\nCo-Authored-By: AI <ai@example.com>", "pr": "" }
}
```

**`invalid_ui_settings/input/settings.json`:**
```json
{
  "defaultShell": "zsh",
  "statusLine": "not-an-object",
  "spinnerVerbs": { "mode": "unknown" },
  "attribution": 42
}
```

### 4. Tests

- Valid parsing of all scalar and object keys
- `defaultShell` enum validation
- `spinnerVerbs.mode` enum validation
- `attribution` object parsing with `commit` and `pr`
- Non-object values for structured keys → warning
- `includeCoAuthoredBy` backward compatibility unaffected
- `showTurnDuration`/`terminalProgressBarEnabled` NOT parsed here

## Acceptance criteria

- [ ] All 7 scalar keys parse correctly
- [ ] All 4 structured objects parse into typed models
- [ ] `attribution.commit` and `attribution.pr` parse correctly
- [ ] `statusLine.padding` parses as optional integer
- [ ] Enum validations work for `defaultShell` and `spinnerVerbs.mode`
- [ ] Non-object structured values produce warnings
- [ ] `includeCoAuthoredBy` backward compatibility maintained
- [ ] Full test suite passes

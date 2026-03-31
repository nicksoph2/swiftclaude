# Packet J1: Remaining ~/.claude.json Keys

## Overview

This packet expands `~/.claude.json` parsing with 6 verified global config keys that live exclusively in `~/.claude.json` (NOT in `settings.json`). These are documented in the official Claude Code settings page under "Global config settings".

## Prerequisites

- G1 and G2 completed (or can proceed independently if ClaudeJsonParser is updated directly)

## Pre-read files

- `ClaudeConfigManager/Infrastructure/Parsers/ClaudeJsonParser.swift`
- `ClaudeConfigManagerTests/Parsers/ClaudeJsonParserTests.swift`
- `Documents/AGENT_FRAMEWORK.md` — Section 11 (last subsection: ~/.claude.json-only keys)

## Baseline (preserve existing)

- `globalPreferences` (defaultModel, defaultMode, telemetryEnabled)
- `mcp` (user and local server collections)
- `trust` (trustedProjectPaths, blockedProjectPaths)

## New verified keys

These 6 keys are documented as ~/.claude.json-only. Adding them to settings.json triggers a schema validation error.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `autoConnectIde` | `Bool` | false | Auto-connect to running IDE from external terminal |
| `autoInstallIdeExtension` | `Bool` | true | Auto-install IDE extension in VS Code terminal |
| `editorMode` | `String` | `"normal"` | Key binding mode: `"normal"` or `"vim"` |
| `showTurnDuration` | `Bool` | true | Show turn duration messages after responses |
| `terminalProgressBarEnabled` | `Bool` | true | Show terminal progress bar in supported terminals |
| `teammateMode` | `String` | `"auto"` | Agent team display: `"auto"`, `"in-process"`, or `"tmux"` |

## Deliverables

### 1. Updated `ParsedClaudeJsonDocument`

Add 6 new typed fields:
```swift
let autoConnectIde: Bool?
let autoInstallIdeExtension: Bool?
let editorMode: String?           // "normal" or "vim"
let showTurnDuration: Bool?
let terminalProgressBarEnabled: Bool?
let teammateMode: String?         // "auto", "in-process", or "tmux"
```

### 2. Parser updates in `ClaudeJsonParser.swift`

- Parse all 6 keys from the top-level JSON object
- Validate `editorMode` as enum: `["normal", "vim"]`
- Validate `teammateMode` as enum: `["auto", "in-process", "tmux"]`
- Invalid enum values → warning-level issue
- Add these 6 key names to the `settingsFamilyKeys` set (the list of keys that should NOT appear in settings.json)

### 3. Cross-file key placement warnings

The existing ClaudeJsonParser detects settings.json keys placed incorrectly in claude.json. Add the reverse:
- In `SettingsParser.swift`, detect these 6 claude.json-only keys and emit a warning if found in settings.json
- Warning message: "Key '\(key)' belongs in ~/.claude.json, not settings.json"

### 4. Fixtures

**`Fixtures/parsers/claude_json/valid_global_config/input/.claude.json`:**
```json
{
  "$schema": "...",
  "autoConnectIde": true,
  "autoInstallIdeExtension": false,
  "editorMode": "vim",
  "showTurnDuration": false,
  "terminalProgressBarEnabled": true,
  "teammateMode": "tmux",
  "globalPreferences": {
    "defaultModel": "claude-sonnet-4-6"
  }
}
```

**`Fixtures/parsers/claude_json/invalid_global_config_enums/input/.claude.json`:**
```json
{
  "editorMode": "emacs",
  "teammateMode": "split-screen"
}
```

**`Fixtures/parsers/settings/misplaced_claude_json_keys/input/settings.json`:**
```json
{
  "editorMode": "vim",
  "teammateMode": "auto"
}
```

### 5. Tests

- Valid parsing of all 6 keys
- Enum validation for `editorMode` and `teammateMode`
- Invalid enum values → warning
- Cross-file detection: claude.json keys in settings.json → warning
- Existing `globalPreferences`, `mcp`, `trust` parsing unaffected

## Acceptance criteria

- [ ] All 6 global config keys parse into typed fields
- [ ] `editorMode` enum validation works
- [ ] `teammateMode` enum validation works
- [ ] Claude.json keys found in settings.json produce warnings
- [ ] Existing ClaudeJsonParser behavior does not regress
- [ ] Full test suite passes

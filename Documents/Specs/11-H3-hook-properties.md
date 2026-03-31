# Packet H3: Hook Properties and Global Hook Controls

## Overview

This packet extends hook action parsing to capture all current Claude Code hook handler fields and global hook-disabling behavior. It also corrects a critical data model error where the timeout field uses milliseconds instead of the documented seconds.

## Prerequisites

- G2 completed
- H1 completed (event catalog)
- H2 completed (handler types)

## Pre-read files

- `ClaudeConfigManager/Infrastructure/Parsers/SettingsParser.swift` — current `ParsedHookAction`
- `ClaudeConfigManagerTests/Parsers/SettingsParserTests.swift` — existing hook tests
- `ClaudeConfigManagerTests/Fixtures/parsers/settings/` — existing fixtures
- `Documents/AGENT_FRAMEWORK.md` — Sections 9-10 (Hook Events and Handler Types)

## Critical fix: timeoutMs → timeout

The current `ParsedHookAction` has `timeoutMs: Int?` parsed from JSON key `"timeoutMs"`. The official Claude Code docs specify `timeout` in **seconds**, not milliseconds.

**Required changes:**
1. Rename `ParsedHookAction.timeoutMs` to `ParsedHookAction.timeout`
2. Change JSON parsing key from `"timeoutMs"` to `"timeout"`
3. Update all fixture files that reference `timeoutMs`
4. Update all test assertions that reference `timeoutMs`
5. Search the entire codebase for any other references to `timeoutMs` and update
6. The type remains `Int?` — the unit changes from milliseconds to seconds

## Required hook handler properties

### Common properties (all handler types)

| Property | Swift name | Type | Description |
|----------|-----------|------|-------------|
| `type` | `type` | `String` (required) | `"command"`, `"http"`, `"prompt"`, `"agent"` |
| `timeout` | `timeout` | `Int?` | Seconds before canceling. Defaults: 600 (command), 30 (prompt), 60 (agent) |
| `statusMessage` | `statusMessage` | `String?` | Custom spinner message during execution |
| `if` | `condition` | `String?` | Permission rule syntax filter (tool events only) |
| `once` | `once` | `Bool?` | Run only once per session (skills only). Default: false |

### Command-specific properties

| Property | Swift name | Type | Description |
|----------|-----------|------|-------------|
| `command` | `command` | `String` (required) | Shell command to execute |
| `async` | `isAsync` | `Bool?` | Run in background without blocking. Default: false |
| `shell` | `shell` | `String?` | `"bash"` (default) or `"powershell"` |

### HTTP-specific properties

| Property | Swift name | Type | Description |
|----------|-----------|------|-------------|
| `url` | `url` | `String` (required) | POST endpoint URL |
| `headers` | `headers` | `[String: String]?` | HTTP headers (supports `$VAR_NAME` interpolation) |
| `allowedEnvVars` | `allowedEnvVars` | `[String]?` | Env vars allowed in header interpolation |

### Prompt/Agent-specific properties

| Property | Swift name | Type | Description |
|----------|-----------|------|-------------|
| `prompt` | `prompt` | `String` (required) | Prompt text (`$ARGUMENTS` for input JSON) |
| `model` | `model` | `String?` | Model for evaluation (fast model by default) |

## Global hook controls

| Key | Type | Scope | Description |
|-----|------|-------|-------------|
| `disableAllHooks` | `Bool` | Any | Disables all hooks AND any custom status line |
| `allowManagedHooksOnly` | `Bool` | Managed only | Only managed and SDK hooks load |
| `allowedHttpHookUrls` | `[String]` | Any (merge across scopes) | URL patterns HTTP hooks may target |
| `httpHookAllowedEnvVars` | `[String]` | Any (merge across scopes) | Env var names HTTP hooks may interpolate |

## Deliverables

### 1. Updated `ParsedHookAction`

```swift
struct ParsedHookAction {
    let type: String?
    let command: String?           // command hooks
    let url: String?               // http hooks
    let prompt: String?            // prompt/agent hooks
    let timeout: Int?              // RENAMED from timeoutMs — seconds, not ms
    let statusMessage: String?     // all types
    let condition: String?         // "if" field (reserved word)
    let once: Bool?                // skills-only
    let shell: String?             // command hooks: "bash" or "powershell"
    let isAsync: Bool?             // command hooks
    let headers: [String: String]? // http hooks
    let allowedEnvVars: [String]?  // http hooks
    let model: String?             // prompt/agent hooks
}
```

### 2. Parser updates in `SettingsParser.swift`

- Parse all new fields from hook action objects
- Validate `shell` as enum (`"bash"` or `"powershell"`) when present
- Validate `once` as boolean when present
- Parse `headers` as string-to-string object
- Parse `model` as string
- Parse JSON key `"if"` mapping to Swift property `condition`
- Warn on handler-specific properties on wrong type (e.g., `async` on `http` hook)

### 3. Fixtures

**`Fixtures/parsers/settings/valid_hook_all_types/input/settings.json`:**
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "lint.sh",
            "if": "Bash(npm run lint)",
            "timeout": 300,
            "statusMessage": "Running linter...",
            "async": false,
            "shell": "bash"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": ".*",
        "hooks": [
          {
            "type": "http",
            "url": "https://hooks.example.com/notify",
            "headers": { "Authorization": "Bearer $HOOK_TOKEN" },
            "allowedEnvVars": ["HOOK_TOKEN"],
            "timeout": 30,
            "statusMessage": "Notifying..."
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "prompt",
            "prompt": "Review the changes: $ARGUMENTS",
            "model": "claude-haiku-4-5-20251001",
            "timeout": 30
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "agent",
            "prompt": "Validate the user request: $ARGUMENTS",
            "model": "claude-haiku-4-5-20251001",
            "timeout": 60,
            "once": true
          }
        ]
      }
    ]
  },
  "disableAllHooks": false
}
```

**`Fixtures/parsers/settings/invalid_hook_cross_type/input/settings.json`** — handler-specific properties on wrong types (e.g., `async` on `http` hook, `headers` on `command` hook).

### 4. Tests

- All four handler types parse correctly with specific properties
- `timeout` (seconds) replaces `timeoutMs`
- `if` maps to `condition` property
- `once`, `shell`, `model`, `headers`, `allowedEnvVars` parse correctly
- Cross-type property warnings fire
- `disableAllHooks` parses at top level
- All existing hook tests pass (adjusted for timeout rename)

## Acceptance criteria

- [ ] `timeoutMs` no longer appears anywhere in the codebase
- [ ] All four handler types parse with their specific properties
- [ ] `if`, `once`, `shell`, `model`, `headers`, `allowedEnvVars` parse correctly
- [ ] Cross-type property misuse produces warning-level issues
- [ ] `disableAllHooks` is parseable at the top level
- [ ] Hook event semantic metadata (blocking, context injection, prompt erasure) is available for UI display
- [ ] All existing hook tests pass (adjusted for timeout rename)
- [ ] Full test suite passes with zero regressions

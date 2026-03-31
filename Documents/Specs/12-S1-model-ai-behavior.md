# Packet S1: Model and AI Behavior Settings

## Overview

This packet adds parsing for the current model and reasoning-related settings, including the `agent` setting which allows running the main thread as a named subagent.

## Prerequisites

- G1 and G2 completed (registry and typed accessors)

## Pre-read files

- `ClaudeConfigManager/Infrastructure/Parsers/SettingsParser.swift`
- `ClaudeConfigManagerTests/Parsers/SettingsParserTests.swift`
- `Documents/AGENT_FRAMEWORK.md` — Section 11 (Full Settings Surface)

## Required settings

| Key | Type | Validation | Description |
|-----|------|------------|-------------|
| `model` | `String?` | None | Override default model, e.g., `"claude-sonnet-4-6"` |
| `availableModels` | `[String]?` | String array | Restrict selectable models |
| `modelOverrides` | `[String: String]?` | String → string map | Map model IDs to provider IDs |
| `effortLevel` | `String?` | Enum: `"low"`, `"medium"`, `"high"` | Persisted effort level |
| `alwaysThinkingEnabled` | `Bool?` | Boolean | Enable extended thinking by default |
| `fastMode` | `Bool?` | Boolean | Fast mode toggle |
| `fastModePerSessionOptIn` | `Bool?` | Boolean | Fast mode requires per-session opt-in |
| `feedbackSurveyRate` | `Double?` | Range [0.0, 1.0] | Survey probability |
| `agent` | `String?` | None | Named subagent for main thread |

## Important corrections

- `alwaysThinkingEnabled` is currently documented — keep in scope
- preserve existing `autoMode`-family behavior without conflating with model settings
- `agent` is a settings.json key, not agent frontmatter — it names a subagent file

## Deliverables

### 1. Typed fields on parsed settings document

Add all 9 fields. Register in `SettingsKeyRegistry` (if G1 done) with:
- category: `modelAndReasoning`
- merge hint: `selectHighestPrecedence`
- managed-only: none

### 2. Parser updates

- Parse all 9 keys with type checking
- Validate `effortLevel` as closed enum
- Validate `feedbackSurveyRate` range [0, 1]
- Validate `modelOverrides` values are strings
- Emit warnings for invalid values

### 3. Fixtures

**`Fixtures/parsers/settings/valid_model_settings/input/settings.json`:**
```json
{
  "model": "claude-sonnet-4-6",
  "availableModels": ["sonnet", "haiku"],
  "modelOverrides": {
    "claude-opus-4-6": "arn:aws:bedrock:us-east-1:123456789:inference-profile/opus"
  },
  "effortLevel": "medium",
  "alwaysThinkingEnabled": true,
  "fastMode": false,
  "fastModePerSessionOptIn": true,
  "feedbackSurveyRate": 0.05,
  "agent": "code-reviewer"
}
```

**`Fixtures/parsers/settings/invalid_model_settings/input/settings.json`:**
```json
{
  "effortLevel": "turbo",
  "feedbackSurveyRate": 1.5,
  "modelOverrides": { "claude-opus-4-6": 42 }
}
```

### 4. Tests

- Valid parsing of all 9 fields
- Enum validation for `effortLevel`
- Range validation for `feedbackSurveyRate` (0, 0.5, 1.0 valid; 1.5, -0.1 invalid)
- Object shape validation for `modelOverrides`
- `agent` parses as string
- `autoMode`-family unaffected

## Acceptance criteria

- [ ] All 9 settings parse into typed values
- [ ] `effortLevel` enum validation works
- [ ] `feedbackSurveyRate` range validation works
- [ ] `modelOverrides` non-string values produce warning
- [ ] `autoMode`-family unchanged
- [ ] Full test suite passes

# Packet U2: Worktree, Memory, Update, and Remaining Verified Settings

## Overview

This packet closes remaining verified settings gaps after S1-S4 and U1 are done. It adds worktree settings (now a nested object with two keys), operational settings, and any final verified keys.

## Prerequisites

- G1 and G2 completed
- S1-S4 and U1 completed (or at least scoped so no overlap)

## Pre-read files

- `ClaudeConfigManager/Infrastructure/Parsers/SettingsParser.swift`
- `ClaudeConfigManagerTests/Parsers/SettingsParserTests.swift`
- `Documents/AGENT_FRAMEWORK.md` — Section 11

## Required settings

### Worktree (nested object)

| Key | Type | Description |
|-----|------|-------------|
| `worktree.sparsePaths` | `[String]?` | Sparse-checkout paths for worktrees (cone mode) |
| `worktree.symlinkDirectories` | `[String]?` | Directories to symlink from main repo into worktrees |

### Operational settings

| Key | Type | Validation | Description |
|-----|------|------------|-------------|
| `cleanupPeriodDays` | `Int?` | ≥ 0 | Session cleanup period (0 = disable persistence) |
| `companyAnnouncements` | `[String]?` | String array | Startup announcements (cycled randomly) |
| `plansDirectory` | `String?` | None | Custom plan storage path (relative to project root) |
| `autoUpdatesChannel` | `String?` | Enum: `"stable"`, `"latest"` | Release channel for updates |
| `disableDeepLinkRegistration` | `String?` | Value: `"disable"` | Prevent `claude-cli://` protocol handler |
| `useAutoModeDuringPlan` | `Bool?` | Boolean | Plan mode uses auto mode semantics (default: true) |
| `showClearContextOnPlanAccept` | `Bool?` | Boolean | Show clear context option on plan accept (default: false) |

### Scope restrictions

- `useAutoModeDuringPlan` — not read from shared project settings (`.claude/settings.json`)
- `disableDeepLinkRegistration` — uses string value `"disable"`, not boolean

## Deliverables

### 1. Worktree model

```swift
struct ParsedWorktreeConfig {
    let sparsePaths: [String]?
    let symlinkDirectories: [String]?
    let unknownFields: [String: JSONValue]?
}
```

### 2. Parser updates

- Parse `worktree` as JSON object with two array-of-string fields
- Parse all 7 operational settings with type checking
- Validate `autoUpdatesChannel` as enum: `["stable", "latest"]`
- Validate `cleanupPeriodDays` ≥ 0 (negative values → warning)
- Note special behavior: `cleanupPeriodDays: 0` disables persistence entirely
- Validate `disableDeepLinkRegistration` expected value is `"disable"` (other strings → warning)
- Preserve unknown worktree fields for forward compat

### 3. Registry entries (if G1 done)

- `worktree.sparsePaths`: category `worktree`, merge `appendUnique`
- `worktree.symlinkDirectories`: category `worktree`, merge `appendUnique`
- `useAutoModeDuringPlan`: scope restriction — not from shared project settings
- All others: `selectHighestPrecedence`

### 4. Fixtures

**`valid_worktree_and_ops/input/settings.json`:**
```json
{
  "worktree": {
    "sparsePaths": ["packages/my-app", "shared/utils"],
    "symlinkDirectories": ["node_modules", ".cache"]
  },
  "cleanupPeriodDays": 20,
  "companyAnnouncements": ["Welcome to Acme Corp!"],
  "plansDirectory": "./plans",
  "autoUpdatesChannel": "stable",
  "disableDeepLinkRegistration": "disable",
  "useAutoModeDuringPlan": false,
  "showClearContextOnPlanAccept": true
}
```

**`valid_cleanup_zero/input/settings.json`:**
```json
{ "cleanupPeriodDays": 0 }
```

**`invalid_worktree_ops/input/settings.json`:**
```json
{
  "worktree": "not-an-object",
  "cleanupPeriodDays": -5,
  "autoUpdatesChannel": "nightly",
  "disableDeepLinkRegistration": true
}
```

### 5. Tests

- Worktree object with both fields
- Worktree with only one field
- All 7 operational settings parse
- `autoUpdatesChannel` enum validation
- `cleanupPeriodDays` negative → warning, zero → valid with special semantics
- `disableDeepLinkRegistration` non-"disable" string → warning, boolean → type mismatch
- Non-object `worktree` → error

## Acceptance criteria

- [ ] Both worktree keys parse in nested object
- [ ] All 7 operational settings parse
- [ ] Enum/range validations work
- [ ] Special `cleanupPeriodDays: 0` behavior documented
- [ ] Scope restriction noted for `useAutoModeDuringPlan`
- [ ] Full test suite passes

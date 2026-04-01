# Packet 04 Handoff — Typed Accessor Layer

## Summary

Packet 04 implements a lightweight typed accessor layer for extracting configured values from the parsed settings document. The accessor structs provide nil-safe, typed access to grouped settings families.

## Files Created

1. **`ClaudeConfigManager/Infrastructure/Parsers/SettingsAccessors.swift`** (323 lines)
   - `ModelSettings` — model, smallModel, largeModel, maxTokens, temperature
   - `PermissionSettings` — allowRules, denyRules, askRules, defaultMode, additionalDirectories, disableBypassPermissionsMode
   - `HookPolicySettings` — hooksEnabled (true unless explicitly false), handlers(for event:), allowedHTTPHookURLs, httpHookAllowedEnvVars
   - `MCPPolicySettings` — disabledServers, enabledServers, allowManagedMcpServersOnly, enableAllProjectMcpServers, allowedMcpServers, deniedMcpServers
   - `SandboxSettings` — enabled, failIfUnavailable, autoAllowBashIfSandboxed, excludedCommands, allowUnsandboxedCommands, enableWeakerNetworkIsolation, allowedDomains, httpProxyPort, socksProxyPort, enableWeakerNestedSandbox
   - `UISettings` — outputFormat, language, verbose, debug, showTurnDuration, voiceEnabled, prefersReducedMotion, spinnerTipsEnabled, showClearContextOnPlanAccept, defaultShell, respectGitignore
   - `WorktreeSettings` — config, plansDirectory, autoMode, disableAutoMode, useAutoModeDuringPlan
   - `AttributionSettings` — commit, pr, includeCoAuthoredBy, includeGitInstructions
   - Extension on `SettingsDocumentValue` providing convenience computed properties for each group

2. **`ClaudeConfigManagerTests/Parsers/SettingsAccessorTests.swift`** (485 lines)
   - Comprehensive test coverage for all 8 accessor groups
   - 40+ test methods covering:
     - Correct value extraction
     - Missing keys returning nil/default
     - Wrong JSON types returning nil (not crashing)
     - Empty arrays for missing nested collections
   - Tests for each accessor group:
     - `testModelSettings*` (7 tests)
     - `testPermissionSettings*` (7 tests)
     - `testHookPolicySettings*` (8 tests)
     - `testMCPPolicySettings*` (5 tests)
     - `testSandboxSettings*` (5 tests)
     - `testUISettings*` (7 tests)
     - `testWorktreeSettings*` (2 tests)
     - `testAttributionSettings*` (3 tests)

## Files Modified

- **`ClaudeConfigManager/Infrastructure/Parsers/SettingsAccessors.swift`** — Fixed `handlers(for:)` method to use `action.rawObject` instead of incorrect `action.rawValue`
- **`ClaudeConfigManagerTests/Parsers/SettingsAccessorTests.swift`** — Fixed two test methods that had incorrect variable references (`value` → `document`)

## Design Decisions

### Accessor Pattern

- Lightweight value type structs holding a reference to `SettingsDocumentValue`
- All properties are computed (no storage)
- Nil-safe access with type checking
- Return empty arrays for collection-type properties when not set (convenience over optionals)

### Typing Strategy

- Leverage existing parsed types from SettingsParser (e.g., `ParsedPermissions`, `ParsedSandboxConfig`, `ParsedWorktreeConfig`)
- Direct property mapping where possible (e.g., `value.model → String?`)
- Custom extraction helpers for keys stored in `keyedStorage` (e.g., `maxTokens`, `temperature` from `[String: JSONValue]`)
- All accessors are nil-safe; wrong types return nil, not crash

### Extension on SettingsDocumentValue

Convenience computed properties allow usage like:
```swift
let settings = document.value
let modelSettings = settings.modelSettings  // Returns ModelSettings struct
let maxTokens = modelSettings.maxTokens    // Returns Int?
```

### Test Coverage

Tests verify:
1. Correct typed values extracted from valid JSON
2. Nil returned for missing keys
3. Nil returned for wrong JSON types (type safety)
4. Default empty arrays for missing collections
5. Nested property access (e.g., `sandbox.network.allowedDomains`)

## Build and Test

Files are registered automatically via `project.yml` with `path: .` source inclusion.

Expected test count: 45+ test methods across all accessor groups.

## Known Issues & Decisions

1. **handlers(for:) Implementation** — Returns raw JSONValue objects rather than typed action structures, as actions vary by type and need flexible representation
2. **Type Extraction from keyedStorage** — Uses pattern matching on JSONValue enum for type-safe extraction
3. **Empty Arrays vs Nil** — Collection properties return empty arrays when not set (convenience) rather than optional arrays (consistency with resolver behavior)

## Recommended Next Packet

With the accessor layer complete:
- Implement UI display helpers that use typed accessors to show settings
- Create validation logic that uses accessors to check for conflicting settings
- Add merge logic in resolver that uses accessor patterns for multi-scope resolution
- Implement settings editor backed by accessor types


# Packet 07 — Schema Validation Engine

## Context

Parsers currently emit syntax-level issues (malformed JSON, wrong field types). This packet adds a **schema validation layer** that runs after parsing and catches semantic type errors, illegal enum values, scope-restriction violations, and mutually exclusive key combinations — all driven by the `SettingsKeyRegistry` built in Packet 03.

The validation issues it produces will feed the validation aggregation view (a later packet) and block saves in the editing flow (a much later packet). For now, the goal is to get the issues emitted and visible in the existing parse result surface.

**Prerequisites: Packets 01 and 03 must be complete.**

## Prerequisites

- Packet 01 (pipeline wiring), Packet 03 (key registry) complete

## Deliverables

### 1. `SettingsValidator.swift`

Create `ClaudeConfigManager/Infrastructure/Parsers/SettingsValidator.swift`.

```swift
struct SettingsValidator {
    /// Validate a parsed SettingsDocument against the key registry.
    /// Returns an array of SyntaxIssues — does not throw.
    func validate(_ document: SettingsDocument, at scope: ResolutionScope) -> [SyntaxIssue]
}
```

The validator must emit the following issue types (add to `SyntaxIssue` if not already present):

| Issue case | When emitted |
|---|---|
| `.invalidFieldType(key, expected, got)` | Value is the wrong type for a registered key |
| `.invalidEnumValue(key, value, validValues)` | Value is not in the enumerated set for that key |
| `.scopeRestrictionViolated(key, scope)` | Key is `managedOnly` but found at a non-managed scope, or `notAtManaged` but found at managed scope |
| `.unknownKey(key)` | Key is not in the registry (info level, not error) |
| `.mutuallyExclusiveKeys(key1, key2)` | Both keys are present when they cannot coexist |
| `.deprecatedKey(key, suggestion)` | Key is marked deprecated in the registry |

**Mutually exclusive pairs to enforce** (look at the existing parser and registry to confirm these):
- `includeCoAuthoredBy` and `attribution` cannot both be present with values

### 2. Wire validation into `SettingsParser`

After the parser produces a `ParseResult<SettingsDocument>`, run `SettingsValidator.validate(document, at: scope)` and merge the resulting issues into the `ParseResult.issues` array. The scope must be threaded through to the parser. Look at how the existing parser is called to understand how to pass the scope.

If the scope is not currently a parameter to `SettingsParser.parse(...)`, add it. Update all call sites.

### 3. `ClaudeJsonValidator.swift` (lightweight)

Create a minimal `ClaudeJsonValidator` that validates the six new keys from Packet 06 (correct types, no unknown keys). Follow the same pattern as `SettingsValidator`. Wire it into `ClaudeJsonParser`.

### 4. Unit tests

Create `ClaudeConfigManagerTests/Parsers/SettingsValidatorTests.swift`:

- **`testManagedOnlyKeyAtUserScope`** — a settings document with a managed-only key parsed at `.user` scope → emits `.scopeRestrictionViolated`
- **`testInvalidEnumValue`** — `outputFormat` set to `"xml"` → emits `.invalidEnumValue`
- **`testUnknownKeyEmitsInfoIssue`** — unknown key in settings → emits `.unknownKey` at info severity
- **`testDeprecatedKeyEmitsInfo`** — `includeCoAuthoredBy` present → emits `.deprecatedKey`
- **`testMutuallyExclusiveKeys`** — both `includeCoAuthoredBy` and `attribution` present → emits `.mutuallyExclusiveKeys`
- **`testValidDocumentEmitsNoErrors`** — a well-formed document at an appropriate scope → zero error/warning issues

All existing tests must continue to pass.

### 5. Verify issues surface in the UI

After wiring, open the app on a machine with real config files. Navigate to any scope view that shows parse issues. Confirm that a deliberately misconfigured settings file (e.g. wrong type for a known key) produces a visible issue in the parsing stage. This is a manual smoke test — document it in the done criteria confirmation.

## Build and Test

```bash
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager \
  -destination 'platform=macOS' -quiet 2>&1 | tail -30
```

**Done criteria:**
- All new validator tests pass
- All existing tests pass
- Build has zero warnings
- Manual smoke: a misconfigured settings file produces a visible parse issue in the app's Parsing stage

## Handover Note

Only create `Documents/07-handoff.md` if work deviated from the plan. Record what was completed, what was not, any difficulty adding scope as a parser parameter, and recommended next step.

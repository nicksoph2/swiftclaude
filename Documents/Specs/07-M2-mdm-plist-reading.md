# Packet M2: MDM Plist Reading

## Overview

This packet implements reading of managed settings delivered via macOS MDM (Mobile Device Management) using the plist domain `com.anthropic.claudecode`. The implementation provides a reusable `MDMPolicyReader` that discovers and converts plist-typed data to the app's `JSONValue` representation, enabling MDM policies to participate in the configuration resolution hierarchy at the managed scope level with full type safety and error handling.

## Prerequisites

- M1 completed (managed settings discovery infrastructure exists)
- Foundation framework available (UserDefaults, CFPreferences)
- JSONValue type available from SettingsParser.swift
- SyntaxIssue and ParseResult types available for error reporting

## Files to Read Before Starting

1. `ClaudeConfigManager/Infrastructure/Parsers/SettingsParser.swift` (lines 62-108 for JSONValue and ParseResult types)
2. `ClaudeConfigManager/Infrastructure/Discovery/RootLocator.swift` (context on managed settings scopes)
3. `ClaudeConfigManager/Infrastructure/Resolver/ResolverModels.swift` (ResolutionSource, MergeMethod types)

## Deliverables

### 1. MDMPolicyReader (`ClaudeConfigManager/Infrastructure/Discovery/MDMPolicyReader.swift`)

**Purpose**: Reads managed settings from macOS MDM plist domain and converts to typed JSONValue dictionary for integration into the managed scope.

**Types to create**:

- `protocol MDMPolicyReading`: Interface for dependency injection
  - `func readPolicies() -> ParseResult<[String: JSONValue]>` — reads all keys from MDM domain, returns typed dictionary with issues

- `struct MDMPolicyReader: MDMPolicyReading`: Concrete implementation
  - `init()` — default initializer
  - `func readPolicies() -> ParseResult<[String: JSONValue]>` — implementation using UserDefaults or CFPreferences
  - `private func convertToJSONValue(_ value: Any) -> JSONValue?` — converts plist types to JSONValue, returns nil for unsupported types (NSData, NSDate)
  - `private func readFromUserDefaults() -> [String: Any]?` — attempts to read using UserDefaults(suiteName:)
  - `private func readFromCFPreferences() -> [String: Any]?` — fallback using CFPreferencesCopyAppValue (macOS API)

**Integration points**:
- Used by `ManagedSettingsResolver` (packet M3) to read MDM tier
- Returns ParseResult so unsupported types generate `.info` severity issues
- Converts NSString, NSNumber, NSArray, NSDictionary, NSNull to JSONValue
- Skips NSData and NSDate with `.info` issue: "MDM key '\(key)' has unsupported plist type NSData/NSDate"

**Edge cases to handle**:
- MDM domain not found: returns empty dictionary with no issues
- Plist contains NSData: skipped with info issue
- Plist contains NSDate: skipped with info issue
- Mixed type array [NSString, NSNumber]: converts each element independently
- Nested NSDictionary with mixed types: recursive JSONValue conversion

### 2. Modifications to Existing Files

**File**: None — this is a new component

## Test Specification

### Test File: `ClaudeConfigManagerTests/Discovery/MDMPolicyReaderTests.swift`

**Test cases**:

1. `testReadPoliciesWithEmptyDomain`: Setup → Call readPolicies() when MDM domain is empty → Expect ParseResult with empty dictionary, no issues
2. `testReadPoliciesWithSimpleTypes`: Setup → Mock UserDefaults with string, number, bool, null → Expect all converted to JSONValue correctly
3. `testReadPoliciesWithArrays`: Setup → Mock UserDefaults with string array, number array, mixed array → Expect arrays converted to JSONValue.array([...])
4. `testReadPoliciesWithNestedObjects`: Setup → Mock UserDefaults with nested NSDictionary → Expect recursive conversion to JSONValue.object
5. `testReadPoliciesWithUnsupportedTypes`: Setup → Include NSData and NSDate in domain → Expect info issues for each unsupported type, keys excluded from result
6. `testReadPoliciesWithMixedValidAndUnsupported`: Setup → Dictionary with string, NSData, number, NSDate → Expect result contains string and number, issues for NSData/NSDate
7. `testMDMPolicyReadingProtocol`: Setup → Create mock implementation of MDMPolicyReading → Expect protocol adoption works with DI injection

### Test Fixtures

For each test fixture, create directory structure:

**Fixture 1**: `Fixtures/mdm/empty-domain/`
- No input files needed (test mocks empty result)
- Expected: Empty dictionary `{}`

**Fixture 2**: `Fixtures/mdm/simple-types/`
- Input mock result:
  ```swift
  [
    "stringKey": "value",
    "numberKey": NSNumber(42),
    "boolKey": NSNumber(true),
    "nullKey": NSNull()
  ]
  ```
- Expected dictionary:
  ```swift
  [
    "stringKey": .string("value"),
    "numberKey": .number(42.0),
    "boolKey": .bool(true),
    "nullKey": .null
  ]
  ```

**Fixture 3**: `Fixtures/mdm/arrays/`
- Input mock:
  ```swift
  [
    "stringArray": ["a", "b", "c"],
    "numberArray": [NSNumber(1), NSNumber(2)],
    "mixedArray": ["text", NSNumber(42), NSNumber(true), NSNull()]
  ]
  ```
- Expected:
  ```swift
  [
    "stringArray": .array([.string("a"), .string("b"), .string("c")]),
    "numberArray": .array([.number(1.0), .number(2.0)]),
    "mixedArray": .array([.string("text"), .number(42.0), .bool(true), .null])
  ]
  ```

**Fixture 4**: `Fixtures/mdm/nested-objects/`
- Input mock:
  ```swift
  [
    "config": [
      "nested": [
        "value": "deep"
      ]
    ]
  ]
  ```
- Expected:
  ```swift
  [
    "config": .object([
      "nested": .object(["value": .string("deep")])
    ])
  ]
  ```

**Fixture 5**: `Fixtures/mdm/unsupported-types/`
- Input mock with NSData and NSDate objects
- Expected: Dictionary excludes those keys, ParseResult.issues contains 2 `.info` issues

## Acceptance Criteria

1. MDMPolicyReader.readPolicies() successfully reads from `com.anthropic.claudecode` plist domain
2. NSString, NSNumber, NSArray, NSDictionary, NSNull convert to correct JSONValue variants
3. NSData and NSDate skipped with `.info` issue severity
4. Returns ParseResult<[String: JSONValue]> with typed value and optional issues array
5. Integrates with MDMPolicyReading protocol for test mocking
6. All existing tests continue to pass
7. No external dependencies beyond Foundation
8. Thread-safe for concurrent reads (UserDefaults is thread-safe)

## Out of Scope

- Monitoring plist changes for live updates (read once per app launch)
- Writing back to MDM domain (read-only)
- Other MDM payloads outside `com.anthropic.claudecode` domain
- Decryption of protected MDM payloads (assume plaintext plist)

## Build Verification

```bash
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager -destination 'platform=macOS' -quiet
```

Expected: All tests pass, including new MDMPolicyReaderTests.

## Handoff Notes Template

Create `Documents/M2-handoff.md`:

```markdown
# M2 Handoff: MDM Plist Reading

## Files Created
- ClaudeConfigManager/Infrastructure/Discovery/MDMPolicyReader.swift
- ClaudeConfigManagerTests/Discovery/MDMPolicyReaderTests.swift

## Files Modified
None

## Key Decisions
- Used UserDefaults(suiteName:) as primary method, CFPreferences as fallback for robustness
- Info severity for unsupported types (NSData, NSDate) to avoid blocking config loading
- JSONValue enum chosen for type-safe representation of plist values

## Issues & Open Questions
- CFPreferences fallback may require linking CoreFoundation framework
- Consider performance impact of domain scanning on app startup

## Next Steps
- M3 will integrate MDMPolicyReader into ManagedSettingsResolver
```

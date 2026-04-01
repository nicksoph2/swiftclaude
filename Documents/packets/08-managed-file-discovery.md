# Packet 08 — Managed File Discovery and MDM Reading

## Context

The managed scope is the highest-precedence tier in Claude Code's configuration hierarchy but the app currently shows placeholder content for it. Before the managed UI can be built, the app must be able to discover managed config files on disk and read MDM-delivered preferences. This packet implements both discovery mechanisms.

**Prerequisite: Packet 01 must be complete.**

## Prerequisites

- Packet 01 complete (pipeline wiring fixed, all tests green)

## Deliverables

### Part A — Managed File Discovery

#### 1. Read existing discovery code

Read `ClaudeConfigManager/Infrastructure/Discovery/` to understand `WorkspaceScanner` and `RootLocator`. Understand the current `ScanResult` type and how it represents discovered files.

#### 2. Managed file paths

The managed tier lives at these paths:
- `/Library/Application Support/ClaudeCode/managed-settings.json` — single file
- `/Library/Application Support/ClaudeCode/managed-settings.d/*.json` — directory of files, merged lexicographically
- `/Library/Application Support/ClaudeCode/managed-mcp.json` — MCP policy
- `/Library/Application Support/ClaudeCode/CLAUDE.md` — managed instructions

These paths are system paths that require no sandbox bookmark. They either exist and are readable, or they do not.

#### 3. `ManagedFileLocator.swift`

Create `ClaudeConfigManager/Infrastructure/Discovery/ManagedFileLocator.swift`:

```swift
struct ManagedFileLocator {
    /// Attempt to locate all managed config files.
    /// Returns a ManagedScanResult regardless of whether files exist.
    func locate() -> ManagedScanResult
}

struct ManagedScanResult {
    var settingsFile: DiscoveredFile?             // managed-settings.json
    var settingsOverrideFiles: [DiscoveredFile]   // managed-settings.d/*.json sorted lexicographically
    var mcpFile: DiscoveredFile?                  // managed-mcp.json
    var claudeMdFile: DiscoveredFile?             // CLAUDE.md
}
```

Where `DiscoveredFile` is whatever type the existing scanner uses for a discovered file entry (check the existing code).

For each path:
- If the file does not exist: the property is nil (not an error)
- If the file exists but is not readable: include it as a `DiscoveredFile` with an `.inaccessible` status
- If the file exists and is readable: include it with a `.found` status

For `managed-settings.d/`: if the directory does not exist, `settingsOverrideFiles` is empty. If it exists, enumerate `*.json` files and sort lexicographically by filename.

Handle App Store sandbox restrictions: wrap the file operations in a do/catch and treat `CocoaError.fileReadNoPermission` or `CocoaError.fileNoSuchFile` appropriately. Do not crash or throw.

#### 4. Integrate into `WorkspaceScanner`

Add a `managedResult: ManagedScanResult` property to `ScanResult`. In `WorkspaceScanner.scan()`, call `ManagedFileLocator().locate()` and populate `scanResult.managedResult`. The rest of the scan is unchanged.

#### 5. Discovery tests

Create `ClaudeConfigManagerTests/Discovery/ManagedFileLocatorTests.swift`:

- **`testAllFilesAbsentProducesEmptyResult`** — point the locator at a temp directory where none of the paths exist → all properties nil/empty, no issues
- **`testSettingsFileFoundWhenPresent`** — create a temp file at the expected path → `settingsFile` is non-nil with `.found` status
- **`testOverrideDirSortedLexicographically`** — create three JSON files in a temp `managed-settings.d/` directory in non-alphabetical order → `settingsOverrideFiles` is sorted A→Z

---

### Part B — MDM/Plist Reading

#### 6. `MDMSettingsReader.swift`

Create `ClaudeConfigManager/Infrastructure/Discovery/MDMSettingsReader.swift`:

```swift
struct MDMSettingsReader {
    private let domain = "com.anthropic.claudecode"

    /// Read MDM-managed settings from the system preference domain.
    /// Returns nil if the domain is not present or has no managed values.
    func read() -> MDMSettingsResult?
}

struct MDMSettingsResult {
    var values: [String: JSONValue]   // normalised from plist types
    var source: String                // "MDM (com.anthropic.claudecode)"
}
```

Implementation notes:
- Use `CFPreferencesCopyMultiple(nil, domain as CFString, kCFPreferencesAnyUser, kCFPreferencesCurrentHost)` to read all keys from the managed domain
- If the result is nil or empty, return nil
- Normalise plist values to `JSONValue`:
  - `NSNumber` (bool) → `.bool`
  - `NSNumber` (integer) → `.int`
  - `NSNumber` (double) → `.double`
  - `NSString` → `.string`
  - `NSArray` → `.array` (recursive)
  - `NSDictionary` → `.object` (recursive)
  - Anything else → `.string` with `"\(value)"`

#### 7. Integrate into the managed scan

Add a `mdmResult: MDMSettingsResult?` property to `ManagedScanResult`. In `ManagedFileLocator.locate()`, call `MDMSettingsReader().read()` and store the result.

#### 8. MDM tests

Add to `ManagedFileLocatorTests.swift`:
- **`testMDMReaderReturnsNilWhenDomainAbsent`** — the preference domain `com.anthropic.claudecode` almost certainly does not exist on a developer's machine → `read()` returns nil (this is the expected behaviour on most machines)
- **`testMDMValueNormalisationBool`** — inject a mock `CFPreferences` wrapper (or use dependency injection) to test that `NSNumber` booleans normalise to `JSONValue.bool`

If DI for `CFPreferences` is complex, at minimum write the normalisation logic in a testable pure function and test that in isolation.

## Build and Test

```bash
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager \
  -destination 'platform=macOS' -quiet 2>&1 | tail -30
```

**Done criteria:**
- All new discovery tests pass
- All existing tests pass
- `WorkspaceScanner.scan()` populates `scanResult.managedResult` on every run
- Build has zero warnings

## Handover Note

Only create `Documents/08-handoff.md` if work deviated from the plan. Record what was completed, what was not, any complications with the `CFPreferences` API or sandbox entitlement, and recommended next step.

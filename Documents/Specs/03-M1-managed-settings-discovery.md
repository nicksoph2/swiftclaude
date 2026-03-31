# Packet M1: Managed Settings Discovery (macOS)

## Overview

This packet enables discovery of managed settings files on macOS at platform-specific paths. The app will locate managed settings configuration files (settings.json, mcp.json) in the system Library directory and its drop-in configuration directory, surfacing them in the discovery scanner results. This foundation supports system-wide policy enforcement and admin-controlled configuration.

## Prerequisites

- Packet B3 (Discovery Models) — `DiscoveredFileKind`, `DiscoveredDirectoryKind`, and discovery models must exist
- Packet B2 (WorkspaceScanner) — scanner infrastructure must be in place
- Packet B1 (RootLocator) — path normalization and root resolution utilities available

## Files to Read Before Starting

1. `ClaudeConfigManager/Infrastructure/Discovery/WorkspaceScanner.swift`
2. `ClaudeConfigManager/Infrastructure/Discovery/RootResolutionModels.swift`
3. `ClaudeConfigManager/Infrastructure/Parsers/SettingsParser.swift`
4. `ClaudeConfigManagerTests/Discovery/WorkspaceScannerTests.swift`

## Deliverables

### 1. ManagedSettingsLocator (`ClaudeConfigManager/Infrastructure/Discovery/ManagedSettingsLocator.swift`)

**Purpose**: Encapsulates the logic for discovering managed settings files on macOS at standard locations. Provides a clean, testable interface with protocol-based filesystem abstraction.

**Types to create**:

- `ManagedSettingsLocator`: Struct for discovering managed settings
  - `init(fileSystem: ManagedSettingsFileSystem = DefaultManagedSettingsFileSystem())` — Initializes with optional custom filesystem for testing
  - `locateManagedSettingsFile() -> URL?` — Returns URL of `/Library/Application Support/ClaudeCode/managed-settings.json` if it exists and is readable
  - `locateManagedSettingsDirectory() -> [URL]` — Returns all `.json` files in `/Library/Application Support/ClaudeCode/managed-settings.d/` sorted alphabetically by filename
  - `locateManagedMcpFile() -> URL?` — Returns URL of `/Library/Application Support/ClaudeCode/managed-mcp.json` if it exists and is readable

- `ManagedSettingsFileSystem`: Protocol (trait) for filesystem operations
  - `func fileExists(atPath: String) -> Bool` — Check if a file exists
  - `func isReadable(atPath: String) -> Bool` — Check if a path is readable
  - `func contentsOfDirectory(atPath: String, error: inout NSError?) -> [String]` — List directory contents
  - `func fileExists(atPath: String, isDirectory: inout ObjCBool) -> Bool` — Check existence and type

- `DefaultManagedSettingsFileSystem`: Struct conforming to `ManagedSettingsFileSystem`
  - Uses `FileManager.default` to implement protocol methods
  - `init(fileManager: FileManager = .default)` — Initializes with optional custom FileManager for testing

**Integration points**:
- `WorkspaceScanner.scan()` must be updated to call `ManagedSettingsLocator` and add discovered managed files to the `ScanResult` (see modifications section)
- Managed files should be discovered independently from user/project workspaces
- Discovered managed files appear before user scope files in sorted results

**Edge cases to handle**:
- `/Library/Application Support/ClaudeCode/` directory doesn't exist — return empty results gracefully
- `/Library/Application Support/ClaudeCode/managed-settings.d/` directory is missing — return empty array
- Files exist but are unreadable — surface attributable discovery issues instead of silently omitting them
- `.json` files in managed-settings.d are sorted alphabetically by filename (e.g., `01-base.json`, `02-overrides.json`)
- Drop-in files with non-`.json` extensions are ignored
- `managed-settings.json` and `managed-mcp.json` are optional; if missing, locator returns nil

### 2. Modifications to Existing Files

#### File: `ClaudeConfigManager/Infrastructure/Discovery/RootResolutionModels.swift`

**What changes**:
- Add new cases to `DiscoveredFileKind`:
  - `managedSettingsJSON` — represents `/Library/.../managed-settings.json`
  - `managedSettingsDropIn` — represents drop-in files in `/Library/.../managed-settings.d/*.json`
  - `managedMcpJSON` — represents `/Library/.../managed-mcp.json`

- Add new case to `DiscoveredDirectoryKind`:
  - `managedSettingsRoot` — represents `/Library/Application Support/ClaudeCode/`

**What must NOT change**:
- Do not alter existing enum cases or their ordering
- Do not change DiscoveredFile or DiscoveredDirectory initializers
- Do not modify DiscoveryScopeIdentity or DiscoveryPathID logic

#### File: `ClaudeConfigManager/Infrastructure/Discovery/WorkspaceScanner.swift`

**What changes**:
- Add a new private method: `func scanManagedSettingsScope(issues: inout [DiscoveryIssue]) -> (files: [DiscoveredFile], directories: [DiscoveredDirectory])`
  - Uses `ManagedSettingsLocator` to discover files
  - Returns discovered managed settings files and directories
  - Creates `DiscoveredFile` and `DiscoveredDirectory` objects with scope `DiscoveryScopeIdentity.managed()` (new static factory)
  - Provenance is `.canonicalExpected` for all managed files
  - Reports issues if managed settings directory is missing or inaccessible

- Update `func scan(_ request: ScanRequest) -> ScanResult`:
  - Before scanning user and project workspaces, call `scanManagedSettingsScope(issues: &issues)`
  - Insert discovered managed files and directories at the **beginning** of the result lists (before user scope)
  - Ensure results are sorted with managed scope first

- Add static factory to `DiscoveryScopeIdentity` (in RootResolutionModels.swift):
  - `static func managed() -> DiscoveryScopeIdentity` — creates scope with `scopeKind = .managed` and `project = nil`
  - Update `DiscoveryScopeKind` enum to include case `.managed`

**What must NOT change**:
- Do not alter existing scan behavior for user or project scopes
- Do not change method signatures of existing public methods
- Do not modify DiscoveredWorkspace structure
- Do not break existing test expectations

## Test Specification

### Test File: `ClaudeConfigManagerTests/Discovery/ManagedSettingsLocatorTests.swift`

**Test cases**:

1. `testLocateManagedSettingsFile_WhenFileExists_ReturnsURL`:
   - Setup: Mock filesystem returns true for `/Library/Application Support/ClaudeCode/managed-settings.json`
   - Action: Call `locateManagedSettingsFile()`
   - Expected: Returns non-nil URL pointing to managed-settings.json

2. `testLocateManagedSettingsFile_WhenFileDoesNotExist_ReturnsNil`:
   - Setup: Mock filesystem returns false for all paths
   - Action: Call `locateManagedSettingsFile()`
   - Expected: Returns nil

3. `testLocateManagedSettingsFile_WhenFileUnreadable_ReturnsNil`:
   - Setup: File exists but `isReadable()` returns false
   - Action: Call `locateManagedSettingsFile()`
   - Expected: Returns nil

4. `testLocateManagedSettingsDirectory_WhenDropInExists_ReturnsSortedURLs`:
   - Setup: Directory `/Library/Application Support/ClaudeCode/managed-settings.d/` contains: `02-override.json`, `01-base.json`, `03-final.json`
   - Action: Call `locateManagedSettingsDirectory()`
   - Expected: Returns three URLs sorted alphabetically: `01-base.json`, `02-override.json`, `03-final.json`

5. `testLocateManagedSettingsDirectory_IgnoresNonJsonFiles`:
   - Setup: Directory contains `01-base.json`, `readme.txt`, `config.yaml`
   - Action: Call `locateManagedSettingsDirectory()`
   - Expected: Returns only the `.json` file URL

6. `testLocateManagedSettingsDirectory_WhenDirectoryMissing_ReturnsEmpty`:
   - Setup: Directory doesn't exist
   - Action: Call `locateManagedSettingsDirectory()`
   - Expected: Returns empty array

7. `testLocateManagedMcpFile_WhenFileExists_ReturnsURL`:
   - Setup: File exists at `/Library/Application Support/ClaudeCode/managed-mcp.json`
   - Action: Call `locateManagedMcpFile()`
   - Expected: Returns non-nil URL

8. `testDefaultManagedSettingsFileSystem_DelegatesTo FileManager`:
   - Setup: Create `DefaultManagedSettingsFileSystem()`
   - Action: Call methods
   - Expected: Methods delegate to FileManager.default correctly

9. `testManagedSettingsLocator_WithCustomFileSystem`:
   - Setup: Create locator with custom mock filesystem
   - Action: Call discovery methods
   - Expected: Uses mock filesystem, not FileManager.default

### Test Fixtures

No fixture files needed for this component (pure unit tests with mocked filesystem).

## Acceptance Criteria

1. `ManagedSettingsLocator` struct exists with three public discovery methods as specified
2. `ManagedSettingsFileSystem` protocol exists with four required methods
3. `DefaultManagedSettingsFileSystem` conforms to the protocol and uses FileManager
4. `DiscoveredFileKind` enum includes three new cases: `managedSettingsJSON`, `managedSettingsDropIn`, `managedMcpJSON`
5. `DiscoveredDirectoryKind` enum includes one new case: `managedSettingsRoot`
6. `DiscoveryScopeKind` enum includes new case: `managed`
7. `DiscoveryScopeIdentity` has new static factory `managed()` that creates correctly-scoped identity
8. `WorkspaceScanner.scan()` calls `scanManagedSettingsScope()` and includes managed files in results
9. Managed scope files appear before user scope files in sorted results
10. All nine test cases pass without errors
11. Existing tests remain unbroken
12. Build succeeds without warnings

## Out of Scope

- Parsing the content of managed-settings.json or managed-mcp.json files (that belongs to parser packets)
- Integration with the resolver or UI layers
- Support for Windows or Linux managed settings (macOS-specific implementation)
- Auto-reloading of managed files when they change on disk
- Conflict detection between managed and user settings

## Build Verification

```bash
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager -destination 'platform=macOS' -quiet 2>&1 | tail -20
```

All tests must pass, including both new tests and all existing discovery, parser, and resolver tests.

## Handoff Notes Template

Create file `Documents/M1-handoff.md` with:
- List of files created: ManagedSettingsLocator.swift
- List of files modified: RootResolutionModels.swift, WorkspaceScanner.swift
- Key decisions: Chose protocol-based filesystem for testability; managed scope files always appear first in results
- Issues encountered: None expected if prerequisites are met
- Recommended next packet: H1 (Hook Event Catalog) or P1 (Permissions Parsing) — both are independent of M1

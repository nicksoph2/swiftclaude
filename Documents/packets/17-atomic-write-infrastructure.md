# Packet 17 — Atomic Write Infrastructure

## Context

Every editing feature (Packets 18 onwards) requires a reliable, safe file write mechanism. This packet builds that foundation: `AtomicFileWriter`, which writes settings files via temp-file-then-rename to prevent partial writes, and validates the post-write pipeline state before committing. It also provides `FileBackupStore` for rollback capability.

Nothing is exposed in the UI yet — this is purely infrastructure and tests.

**Prerequisites: Packets 01 and 07 must be complete.**

## Prerequisites

- Packet 01 (pipeline wiring), Packet 07 (schema validation) complete

## Deliverables

### 1. `AtomicFileWriter.swift`

Create `ClaudeConfigManager/Infrastructure/AtomicFileWriter.swift`.

```swift
final class AtomicFileWriter {
    private let pipeline: ConfigurationPipeline
    private let backupStore: FileBackupStore

    init(pipeline: ConfigurationPipeline, backupStore: FileBackupStore)

    /// Apply a change to a settings file at the given scope.
    /// Validates before writing. Rolls back on post-write failure.
    func write(
        change: SettingsChange,
        to fileURL: URL,
        at scope: ResolutionScope
    ) async throws(WriteError)
}
```

**`SettingsChange`** — describes what to write:
```swift
struct SettingsChange {
    let keyPath: String        // dot-notation key, e.g. "permissions.deny"
    let newValue: JSONValue    // the new value to set
    let operation: ChangeOperation
}

enum ChangeOperation {
    case set           // replace the value at keyPath
    case remove        // remove the key entirely
    case appendToArray(JSONValue)   // append an element to an array key
    case removeFromArray(JSONValue) // remove a matching element from an array key
}
```

**`WriteError`**:
```swift
enum WriteError: Error {
    case fileNotReadable(URL)
    case parseFailure(URL, [SyntaxIssue])
    case schemaValidationFailed([SyntaxIssue])
    case serializationFailed(Error)
    case writeFailed(URL, Error)
    case syncFailed(Error)
    case renameFailed(URL, Error)
    case postWriteValidationFailed(expected: JSONValue, actual: JSONValue?)
    case rolledBack(originalError: WriteError)
}
```

**Write sequence** (must be followed exactly, in order):

1. **Read** the target file into memory. If the file does not exist, start with `{}`. If unreadable, throw `.fileNotReadable`.
2. **Parse** the in-memory JSON into a `SettingsDocument`. If parsing fails with errors (not just warnings), throw `.parseFailure`.
3. **Apply the change** in memory: update the JSON structure at `keyPath` with `newValue`.
4. **Validate** the modified document against the schema (`SettingsValidator`). If validation produces errors, throw `.schemaValidationFailed`. Warnings do not block the write.
5. **Serialize** to canonical JSON: use `JSONEncoder` with `.sortedKeys` and `prettyPrinted` (2-space indent). If serialization fails, throw `.serializationFailed`.
6. **Backup** the original file using `FileBackupStore.backup(fileURL)` (see below).
7. **Write to temp file** at `fileURL.deletingLastPathComponent().appendingPathComponent(".tmp_\(UUID()).json")`. If write fails, throw `.writeFailed`.
8. **fsync** the temp file. Open the file descriptor and call `fsync(fd)`. If this fails, throw `.syncFailed`.
9. **Rename** temp file to `fileURL` using `FileManager.default.moveItem`. If rename fails, throw `.renameFailed`.
10. **Re-run pipeline**: call `await pipeline.run()`.
11. **Verify**: read the new resolved value for `keyPath` from the updated projection. If it does not match `newValue` (for `.set` operations), roll back (restore from `FileBackupStore`) and throw `.postWriteValidationFailed`.
12. **Clear backup** on success: `FileBackupStore.clear(fileURL)`.

### 2. `FileBackupStore.swift`

Create `ClaudeConfigManager/Infrastructure/FileBackupStore.swift`.

```swift
final class FileBackupStore {
    /// Save a copy of fileURL in a temp location. Returns the backup path.
    func backup(_ fileURL: URL) throws -> URL

    /// Restore the backed-up file to its original location.
    func restore(_ fileURL: URL) throws

    /// Remove the backup (called on successful write).
    func clear(_ fileURL: URL)
}
```

Backup location: `URL.temporaryDirectory.appendingPathComponent("ClaudeConfigBackup/<filename>_<timestamp>")`.

### 3. `JSONKeyPathMutator.swift`

Create `ClaudeConfigManager/Infrastructure/JSONKeyPathMutator.swift`.

A pure function that applies a `SettingsChange` to a `JSONValue` tree:

```swift
struct JSONKeyPathMutator {
    func apply(_ change: SettingsChange, to root: JSONValue) throws -> JSONValue
}
```

Handle:
- Dot-notation key paths navigating into nested objects
- Creating intermediate objects if they don't exist (for `.set`)
- Correct array append/remove behaviour
- Throw if the path is invalid for the operation (e.g. appending to a non-array)

### 4. Unit tests

Create `ClaudeConfigManagerTests/Infrastructure/AtomicFileWriterTests.swift`:

- **`testSuccessfulWrite`** — write a setting to a temp file → file contains the new value, no errors
- **`testWriteCreatesFileIfNotExists`** — target file does not exist → file is created with just the new key
- **`testSchemaErrorPreventsWrite`** — change would violate schema → throws `.schemaValidationFailed`, original file unchanged
- **`testRollbackOnPostWriteFailure`** — mock pipeline returns wrong resolved value → throws `.rolledBack`, original file restored
- **`testAtomicityOnRenameFailure`** — inject a rename failure → original file is unchanged
- **`testDotNotationKeyPathSet`** — `JSONKeyPathMutator` sets `"permissions.deny"` correctly in a nested JSON structure
- **`testArrayAppend`** — `appendToArray` adds an element without duplicating existing entries
- **`testArrayRemove`** — `removeFromArray` removes the correct element

## Build and Test

```bash
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager \
  -destination 'platform=macOS' -quiet 2>&1 | tail -30
```

**Done criteria:**
- All atomic write tests pass
- All JSON key path mutator tests pass
- All existing tests pass
- Build has zero warnings
- No UI yet — this is infrastructure only

## Handover Note

Only create `Documents/17-handoff.md` if work deviated from the plan. Record what was completed, what was not, any difficulties with fsync or the temp-rename pattern on macOS sandboxed apps, and recommended next step.

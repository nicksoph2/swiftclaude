# Packet 19 — Pre-Save Resolution Preview and Override Warnings

## Context

This packet completes the editing flow by adding the "Preview Impact" feature: before any change is written to disk, the user sees a structured diff of what will change. It also adds the override conflict warning that fires when a user is about to save a change that will be immediately overridden by a higher-precedence scope.

**Prerequisites: Packets 17 and 18 must be complete.**

## Prerequisites

- Packet 17 (atomic write), Packet 18 (edit mode and recommendation engine) complete

## Deliverables

### 1. In-memory pipeline preview

Add a method to `ConfigurationPipeline` (or a new `PipelinePreview` type) that runs the full resolution pipeline in memory with a proposed change applied, without touching any files:

```swift
extension ConfigurationPipeline {
    /// Run an in-memory simulation of the pipeline with `change` applied at `scope`.
    /// Does not write to disk. Returns the projected outcome.
    func preview(
        change: SettingsChange,
        at scope: ResolutionScope,
        fileURL: URL
    ) async -> PreviewResult
}

struct PreviewResult {
    let proposedProjection: SessionProjection
    let affectedKeys: [KeyDelta]      // keys whose resolved value would change
    let targetFilePreview: String     // the canonical JSON that would be written
    let error: WriteError?            // if the change would be invalid
}

struct KeyDelta {
    let keyPath: String
    let before: JSONValue?
    let after: JSONValue?
    let winningScope: ResolutionScope
}
```

Implementation: apply the `SettingsChange` to an in-memory copy of the target file's content, run validation, then run all resolvers on the modified inputs (without calling `pipeline.run()` which would refresh the actual pipeline state).

### 2. `PreSavePreviewView.swift`

Create `ClaudeConfigManager/Features/Settings/PreSavePreviewView.swift`.

This view is presented as a sheet when the user taps "Preview Impact" in the editor popover (Packet 18). It shows:

**"Effective value after saving"** card:
- Key name
- Before value (struck through if it changes)
- After value (bold, in green if added, amber if changed)

**"Other affected keys"** section (only shown if `affectedKeys.count > 1`):
- A list of other keys whose resolved values would change
- Each row: key name, before value, after value, "Why?" link → opens the Resolution Trace for that key

**"File preview"** expandable section:
- Label: "What will be written to [filename]"
- The `targetFilePreview` string rendered in a monospace scroll view with syntax highlighting (at minimum: keys in one colour, string values in another)
- Non-editable

**Override conflict warning** — if the proposed change would be immediately overridden by a higher-precedence scope (check: does the managed scope or any higher writable scope define the same key with a different value?):
- Show a prominent amber banner: "⚠️ This change may have no effect"
- Explanation: "The [Managed / User] scope already sets [key] to [current value] and takes precedence. Your change will be saved but will be overridden."
- Two actions: "Change target scope" (returns to the scope picker in the editor) and "Save anyway" (proceeds)

**Confirm and save button** (at the bottom):
- Greyed out and replaced with error text if `previewResult.error` is non-nil
- Otherwise: "Confirm and Save to [Scope Name]"
- Tapping calls `AtomicFileWriter.write(...)` and dismisses both the preview sheet and the editor popover on success

**Cancel button** — dismisses the preview, returns to the editor popover

### 3. Wire "Preview Impact" button in editor popover

In the editor popover from Packet 18, enable the "Preview Impact" button. When tapped:
1. Call `pipeline.preview(change:at:fileURL:)` and show a loading indicator
2. On result: present `PreSavePreviewView` as a sheet

### 4. Tests

Create `ClaudeConfigManagerTests/Features/PreSavePreviewTests.swift`:

- **`testPreviewShowsCorrectDelta`** — mock pipeline + a setting change → `affectedKeys` contains the changed key with correct before/after values
- **`testOverrideWarningAppearsWhenHigherScopePresent`** — proposed change at project scope, but managed scope has the same key → override warning is shown
- **`testNoOverrideWarningWhenClear`** — proposed change at user scope, no higher scope defines the key → no warning
- **`testSchemaErrorDisablesConfirmButton`** — a change that fails validation → `previewResult.error` is non-nil, confirm button is disabled

## Build and Test

```bash
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager \
  -destination 'platform=macOS' -quiet 2>&1 | tail -30
```

**Done criteria:**
- "Preview Impact" button works in the editor popover and shows the diff sheet
- File preview shows the exact JSON that would be written
- Override conflict warning appears when a higher scope would nullify the change
- "Confirm and Save" completes the write via `AtomicFileWriter`
- All existing tests pass
- Build has zero warnings

## Handover Note

Only create `Documents/19-handoff.md` if work deviated from the plan. Record what was completed, what was not, any difficulties with the in-memory pipeline simulation, and recommended next step.

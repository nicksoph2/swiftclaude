# Packet 27 — Configuration Snapshots and Named Profiles

## Context

Administrators and practitioners who manage configurations across projects or time need to be able to capture the current state, compare states, and restore known-good configurations. This packet adds snapshot export, named profiles, and a diff view.

**Prerequisites: Packets 01, 09, 16 must be complete.**

## Prerequisites

- Packet 01 (pipeline), Packet 09 (managed resolver), Packet 16 (dashboard) complete

## Deliverables

### 1. Snapshot export (G1)

Add an "Export Snapshot" toolbar button in the dashboard view and in the Pipeline tab toolbar.

**`ConfigurationSnapshotExporter.swift`**:

```swift
struct ConfigurationSnapshotExporter {
    func export(_ projection: SessionProjection, scanResult: ScanResult) -> ConfigurationSnapshot
}

struct ConfigurationSnapshot: Codable {
    let exportedAt: Date
    let appVersion: String
    let resolvedSettings: [SnapshotSettingsEntry]
    let resolvedInstructions: SnapshotInstructionsEntry
    let mcpServers: [SnapshotMcpEntry]
    let permissionRules: SnapshotPermissionsEntry
    let hooks: SnapshotHooksEntry
}
```

Each entry in the snapshot includes:
- The resolved value
- The winning scope and source file path
- All participating scopes and their values (the provenance chain)

**Sensitive value handling**: if a settings key is `env.*` or contains "token", "key", "secret", "password" (case-insensitive), do not export the value. Instead, export `"<redacted>"` with a `"redacted": true` flag.

**Export UI**: Present `NSSavePanel` with default filename `claude-config-snapshot-YYYY-MM-DD.json`. Offer JSON (default) and YAML formats.

**YAML format**: Use a simple Swift YAML serializer (implement a basic one if no dependency is available — YAML for this use case is straightforward nested maps). Alternative: just output well-formatted JSON with a `.yaml` extension if YAML is too complex.

### 2. Named Profiles (G2)

Create `ClaudeConfigManager/Infrastructure/ProfileStore.swift`.

A profile stores the settings for one scope as a named set of key-value pairs — not the full resolved state.

```swift
final class ProfileStore: ObservableObject {
    @Published private(set) var profiles: [ConfigurationProfile]

    func save(_ profile: ConfigurationProfile) throws
    func delete(_ profile: ConfigurationProfile)
    func apply(_ profile: ConfigurationProfile, to scope: ResolutionScope) async throws
}

struct ConfigurationProfile: Codable, Identifiable {
    let id: UUID
    var name: String
    let scope: ResolutionScope
    let settings: [String: JSONValue]   // key-path → value
    let createdAt: Date
    let description: String?
}
```

**Storage**: profiles are stored in `~/.claude/app-profiles.json` — an app-owned file, not a Claude-owned config file. Never mix profile data with actual Claude config files.

**`ProfileManagerView.swift`**: A sheet accessible from a "Profiles" toolbar button:
- List of profiles with name, scope badge, key count, creation date
- "Create profile from current [scope] settings" button → captures current scope's settings into a new profile
- "Apply" button on each profile → shows a change impact preview (uses `pipeline.preview` from Packet 19) before applying
- "Rename" and "Delete" per profile
- "Duplicate" per profile

**Create from current**: reads the current resolved settings for the chosen scope (from `SessionProjection`), filters to only settings that come from that scope as the winner, and creates a `ConfigurationProfile`.

### 3. Configuration Diff View (G3)

Create `ClaudeConfigManager/Features/Diff/ConfigurationDiffView.swift`.

**Two comparison modes**:
1. **Snapshot vs. snapshot**: select two exported snapshot JSON files via `NSOpenPanel`
2. **Current state vs. profile**: select a named profile to compare against the current resolved state

**Diff rendering**:
- Added settings (in the new snapshot but not old): green row with `+` badge
- Removed settings (in old but not new): red row with `-` badge, value shown struck through
- Changed settings: amber row with `~` badge, showing old value → new value
- Unchanged settings: shown in a collapsible "Unchanged ([N] settings)" section

**Filter**: toggle to show only changed settings.

**Export diff**: "Export as Markdown" button — writes a human-readable diff report to disk.

### 4. Tests

- **`testSnapshotRedactsEnvKeys`** — a projection with `env.API_KEY` → snapshot has `"<redacted>"` for that key
- **`testProfileRoundTrip`** — create a profile, save it, load it → settings match
- **`testDiffDetectsAddedKey`** — two snapshots where snapshot B has a new key → diff shows added row
- **`testDiffDetectsChangedValue`** — same key, different value between snapshots → diff shows changed row

## Build and Test

```bash
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager \
  -destination 'platform=macOS' -quiet 2>&1 | tail -30
```

**Done criteria:**
- Export Snapshot produces a valid JSON file with full provenance
- Sensitive env key values are redacted in exports
- Profile manager creates, applies, and deletes profiles
- Applying a profile shows the impact preview before writing
- Diff view correctly shows added/removed/changed settings between two snapshots
- All existing tests pass, build has zero warnings

## Handover Note

Only create `Documents/27-handoff.md` if work deviated from the plan. Record what was completed, what was not, any complexity around the YAML format or iCloud sync (iCloud sync is P3 and can be deferred), and recommended next step.

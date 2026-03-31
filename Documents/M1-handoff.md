# M1 Handoff

## Files Created

- `Documents/M1-handoff.md`

## Files Modified

- `ClaudeConfigManager/Infrastructure/Discovery/RootResolutionModels.swift`
- `ClaudeConfigManager/Infrastructure/Discovery/WorkspaceScanner.swift`
- `ClaudeConfigManagerTests/Discovery/WorkspaceScannerTests.swift`

## Key Decisions

- Added a first-class managed discovery scope and managed root resolution scope so managed files can be surfaced independently from the user workspace.
- Implemented `ManagedSettingsLocator`, `ManagedSettingsFileSystem`, and `DefaultManagedSettingsFileSystem` inside `WorkspaceScanner.swift` instead of a new `ManagedSettingsLocator.swift` file.
- This repo’s Xcode project still uses explicit source-file entries, and project rules prohibit hand-editing the `.xcodeproj`, so keeping the implementation in an already-compiled source file was the safe way to ship M1 without breaking the build.
- Added explicit discovery issues for unreadable managed root, unreadable managed files, unreadable drop-in directory, and drop-in enumeration failure.

## Repo-Specific Spec Adaptations

- The packet spec says `DiscoveredFileKind` and `DiscoveredDirectoryKind` live in `RootResolutionModels.swift`, but in this repo they live in `WorkspaceScanner.swift`, so the enum additions were made there.
- `ScanResult` gained `managedWorkspace` to surface managed discovery cleanly in the current architecture.
- `Documents/IMPLEMENTATION_PLAN_V2.md` mentions `/Library/Application Support/ClaudeCode/CLAUDE.md`, but the authoritative packet spec for M1 only required managed settings JSON and managed MCP discovery, so managed `CLAUDE.md` was left for a later packet.

## Verification

- `xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager -destination 'platform=macOS' -derivedDataPath /tmp/codex-deriveddata-m1 -quiet`

## Assumptions

- Missing managed paths are normal and should still produce canonical managed workspace entries with `.missing` status rather than blocker docs.
- A readable managed root should always be represented even when no managed files are present.
- Keeping the locator in an existing compiled file is preferable to creating an uncompiled source file that the explicit Xcode project would ignore.

## Open Questions / Risks

- If the project later moves to filesystem-synced groups, `ManagedSettingsLocator` should be split into its own file to match the packet spec more closely.
- The managed instruction source (`/Library/Application Support/ClaudeCode/CLAUDE.md`) is still unimplemented and should be handled in the packet that owns managed instruction discovery/resolution.

## Recommended Next Packet

- `M2` — MDM Plist Reading

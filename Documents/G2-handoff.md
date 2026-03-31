# Packet G2 Handoff

## Files modified

- `ClaudeConfigManager/Infrastructure/Parsers/SettingsParser.swift`
- `ClaudeConfigManager/Infrastructure/Parsers/SettingsDocumentValue+Accessors.swift`
- `ClaudeConfigManagerTests/Parsers/SettingsDocumentValueAccessorsTests.swift`

## Key decisions and assumptions

- Added a single keyed storage dictionary to `SettingsDocumentValue` so typed accessors can read both registry-backed values and preserved unsupported top-level values from one place.
- Kept existing named properties intact for backward compatibility, and synthesized keyed storage from those named fields when callers construct `SettingsDocumentValue` directly in tests or resolver helpers.
- Grouped accessor families return top-level configured values for the requested categories instead of flattening every nested registry leaf, which keeps nested families like `sandbox`, `permissions`, and `worktree` usable as objects without duplicating entries.
- Adapted to the current repository state rather than the older minimal G1-era snapshot: the live `SettingsParser.swift` already contains additional packet work beyond the narrow excerpt in the planning docs.

## Verification

- `xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager -destination 'platform=macOS' -quiet`
  - Initial run failed because sandboxed Xcode could not write to the default DerivedData location.
- `xcodebuild -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager -configuration Debug -derivedDataPath .derivedData test CODE_SIGNING_ALLOWED=NO`
  - Passed.

## Open questions / follow-up risks

- `rawValue(for:)` now reads from the unified keyed store, so preserved unsupported top-level values are accessible there as well as through `unsupportedTopLevelKeys`. That is useful for G2, but if any downstream code implicitly assumed raw access only covered recognized keys, it is worth keeping an eye on in later packets.

## Recommended next packet

- `M1` Managed Settings Discovery (macOS)

# V4 Handoff

## Files created or modified

- `ClaudeConfigManager/Features/Managed/ManagedScopeView.swift`
- `ClaudeConfigManager/Infrastructure/Discovery/WorkspaceScanner.swift`
- `ClaudeConfigManagerTests/Discovery/WorkspaceScannerTests.swift`

## What changed

- Replaced the Managed scope placeholder with a live managed-policy inspector UI.
- Added explicit tier reporting for:
  - server-managed settings
  - MDM / OS policy
  - file-based managed settings
- Wired the Managed view to:
  - probe sandbox/access limitations
  - inspect discovered managed files
  - read and parse file-based managed settings
  - read and parse MDM policy values
  - resolve the active managed tier using existing M3 precedence rules
  - summarize managed MCP presence and server ids
  - display managed `CLAUDE.md` content when readable
  - show explicit inaccessible state for managed `CLAUDE.md` and other managed sources
- Extended managed discovery to include `/Library/Application Support/ClaudeCode/CLAUDE.md`.
- Added tests for:
  - managed `CLAUDE.md` discovery
  - file-based managed inspector output
  - MDM suppressing file-based tier in the inspector
  - sandbox-restricted managed `CLAUDE.md` visibility

## Key decisions and assumptions

- Server-managed settings remain represented in the UI, but this packet does not introduce a new live source for them; the inspector reports them as absent unless an upstream source provides them.
- Managed MCP visibility is independent from the managed settings tier row so users can still see file presence even when a higher managed settings tier is active.
- When the managed root is sandbox-restricted or otherwise inaccessible, missing managed files are surfaced as inaccessible in the Managed view instead of being shown as absent.
- The codebase did not automatically compile newly added Swift files into this target in practice, so the managed inspector implementation was embedded into already-targeted source/test files instead of adding new target files. This differs from the doc expectation and should be revisited later if target membership strategy changes.

## Verification

- Ran:
  - `xcodebuild -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager -configuration Debug -derivedDataPath .derivedData test CODE_SIGNING_ALLOWED=NO -destination 'platform=macOS' -quiet`
- Result: passed

## Open questions / follow-up risks

- The app still has no live acquisition path for server-managed settings; the UI is ready for that tier, but detection remains absent unless a future packet adds a source.
- Managed MCP currently shows discovery/presence and parsed server ids, but it is still a summary card rather than a deep inspector.
- The target-membership behavior for new files is worth clarifying because it affects future packet implementation ergonomics.

## Recommended next packet

- `E4` or the next packet in the current sequence after V4, since Managed scope inspection is now implemented and verified.

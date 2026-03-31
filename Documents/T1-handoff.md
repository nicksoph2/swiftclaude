# Packet T1 Handoff

## Files created or modified

- `ClaudeConfigManager/Core/Models/RuntimeSessionSnapshot.swift`
- `ClaudeConfigManager/Infrastructure/Discovery/RuntimeSessionDiscovery.swift`
- `ClaudeConfigManager/Features/Session/RuntimeSessionCardView.swift`
- `ClaudeConfigManager/Features/Session/SessionScopeView.swift`
- `ClaudeConfigManagerTests/Session/RuntimeSessionDiscoveryTests.swift`
- `ClaudeConfigManagerTests/ClaudeConfigManagerTests.swift`
- `ClaudeConfigManagerTests/Fixtures/runtime/README.md`
- `ClaudeConfigManagerTests/Fixtures/runtime/session_snapshot/valid_statusline/input/statusline.json`
- `ClaudeConfigManagerTests/Fixtures/runtime/session_snapshot/valid_statusline/expected/README.md`
- `ClaudeConfigManagerTests/Fixtures/runtime/session_snapshot/partial_statusline/input/statusline.json`
- `ClaudeConfigManagerTests/Fixtures/runtime/session_snapshot/partial_statusline/expected/README.md`
- `ClaudeConfigManagerTests/Fixtures/runtime/session_snapshot/with_worktree/input/statusline.json`
- `ClaudeConfigManagerTests/Fixtures/runtime/session_snapshot/with_worktree/expected/README.md`
- `ClaudeConfigManager.xcodeproj/project.pbxproj`

## Key decisions and assumptions

- Implemented the full documented status-line schema as `Codable` Swift models and projected it into an app-facing `RuntimeSessionSnapshot`.
- Added `RuntimeSessionDiscovery` as a best-effort transcript scanner rooted at `<authorized claude root>/projects`, selecting only primary `<session_id>.jsonl` files directly under project transcript folders and excluding nested subagent transcripts.
- Transcript-derived snapshots intentionally leave cost/context/rate-limit fields empty when the transcript does not expose them; the UI calls out that transcript data is inferred and not live.
- Wired the runtime session UI into `SessionScopeView` as an additive card above the existing session panels.
- The current Xcode project still uses explicit source file enumeration, so new Swift files had to be added to `project.pbxproj` for the app and test targets. This differs from the packet guidance assumption that filesystem additions would be picked up automatically.

## Verification

- `xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager -destination 'platform=macOS' -quiet`
  - Blocked by sandboxed writes to the default DerivedData path.
- `xcodebuild -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager -destination 'platform=macOS' -derivedDataPath .derivedData test CODE_SIGNING_ALLOWED=NO`
  - Passed.

## Open questions / follow-up risks

- Transcript metadata extraction is heuristic by design. It handles status-line-shaped or similarly nested JSON objects, but it is not a formal transcript parser and should be revisited once T2 introduces canonical transcript classification/parsing.
- The runtime card currently refreshes on appearance and global Claude-root changes only. If live polling or file watching is desired, that should land in a later runtime packet rather than expanding T1.
- The UI is intentionally snapshot-focused and read-only; future packets may want stronger formatting for timestamps, rate-limit reset times, or richer context window presentation.

## Recommended next packet

- `T2` to formalize transcript discovery/classification and reduce the heuristic surface area in runtime session inference.

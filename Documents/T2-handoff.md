# T2 Handoff

## Packet

Packet T2: Transcript Discovery and Browsing

## Files Created or Modified

- `ClaudeConfigManager/Core/Models/RuntimeSessionSnapshot.swift`
- `ClaudeConfigManager/Infrastructure/Discovery/RuntimeSessionDiscovery.swift`
- `ClaudeConfigManager/Infrastructure/Parsers/SettingsParser.swift`
- `ClaudeConfigManager/Features/Session/SessionScopeView.swift`
- `ClaudeConfigManagerTests/Session/RuntimeSessionDiscoveryTests.swift`
- `ClaudeConfigManagerTests/Fixtures/runtime/transcripts/valid_transcript/input/transcript.jsonl`
- `ClaudeConfigManagerTests/Fixtures/runtime/transcripts/valid_transcript/expected/README.md`
- `ClaudeConfigManagerTests/Fixtures/runtime/transcripts/malformed_lines/input/transcript.jsonl`
- `ClaudeConfigManagerTests/Fixtures/runtime/transcripts/malformed_lines/expected/README.md`
- `ClaudeConfigManagerTests/Fixtures/runtime/transcripts/unknown_types/input/transcript.jsonl`
- `ClaudeConfigManagerTests/Fixtures/runtime/transcripts/unknown_types/expected/README.md`
- `ClaudeConfigManagerTests/Fixtures/runtime/transcripts/subagent_transcript/input/agent-abc123.jsonl`
- `ClaudeConfigManagerTests/Fixtures/runtime/transcripts/subagent_transcript/expected/README.md`

## What Changed

- Added transcript-domain models for transcript metadata, transcript entries, transcript usage, and transcript discovery errors.
- Added best-effort JSONL transcript parsing that preserves raw JSON per line, keeps malformed lines as entries, and records attributable discovery issues instead of failing the file.
- Added a `TranscriptScanner` service that recursively scans `~/.claude/projects`, classifies primary session vs subagent transcripts, extracts metadata, and loads transcript contents line-by-line.
- Reused the new transcript scanner from `RuntimeSessionDiscovery` so the T1 runtime snapshot path and T2 browser share one transcript interpretation path.
- Added a new Session panel for transcript browsing with:
  - recent primary transcript listing
  - subagent transcript listing for the selected parent session
  - content viewer
  - raw JSON toggle
- Added transcript fixtures and tests covering valid transcripts, malformed lines, unknown record types, subagent classification, empty transcripts, recursive discovery, and metadata extraction.

## Key Decisions and Assumptions

- The transcript record schema is treated as best-effort and non-canonical. Raw JSON stays authoritative for valid lines.
- Malformed lines are preserved as `TranscriptEntry` values with empty `rawJson` and a corresponding discovery issue.
- Primary transcripts are listed in `recentTranscripts`; subagent transcripts are discovered and exposed separately for the selected session.
- Because this project does not auto-add new source files to the Xcode target, the T2 implementation was folded into already-targeted Swift files instead of editing the project file manually.

## Verification

- Ran:
  - `xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager -destination 'platform=macOS' -quiet`

## Open Questions / Risks

- Transcript display remains heuristic-driven. If Claude Code changes transcript record shapes, content previews and model extraction may need updating, but raw JSON preservation should keep the browser usable.
- The current browser exposes read-only transcript browsing only. Search/filtering and richer rendering for tool/result payloads remain future improvements.
- `TranscriptScanner` currently lives in an existing discovery file to avoid manual Xcode project edits. If the project later moves to auto-synced file groups, the code could be split into dedicated files for clarity.

## Recommended Next Packet

- `T4`: Prompt and usage views, since T1 + T2 are now both in place and T4 depends on them.

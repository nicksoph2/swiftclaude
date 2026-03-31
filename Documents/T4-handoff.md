# T4 Handoff — Prompt & Usage Views

## Summary

Implemented Packet T4: Prompt & Usage Views. This packet adds aggregate usage views computed from transcript and runtime session data, providing per-session and cross-session usage summaries, model distribution analysis, and browsable prompt history. All data is computed locally from T1 (RuntimeSessionSnapshot) and T2 (TranscriptScanner) sources — no external API calls.

## Files Created

- `ClaudeConfigManager/Core/Models/UsageModels.swift` — `UsageAggregate`, `ModelUsageBreakdown`, `PromptHistoryEntry`, `UsageComputationError`
- `ClaudeConfigManager/Infrastructure/Discovery/UsageAggregator.swift` — `UsageAggregator` observable service with async computation methods
- `ClaudeConfigManager/Features/Session/UsageDashboardView.swift` — Main usage dashboard with current session, aggregate summary, model breakdown, recent sessions list
- `ClaudeConfigManager/Features/Session/UsageDetailView.swift` — Drilldown detail view for individual session usage
- `ClaudeConfigManager/Features/Session/PromptHistoryView.swift` — Browsable prompt history with search/filter by role, expand to see full content
- `ClaudeConfigManagerTests/Session/UsageModelsTests.swift` — Unit tests for all model types (computed properties, codable roundtrips, factory methods)
- `ClaudeConfigManagerTests/Session/UsageAggregatorTests.swift` — Integration tests for aggregation service (current session, aggregate, error collection)

## Files Modified

- `ClaudeConfigManager/Features/Session/SessionScopeView.swift` — Added `usage` case to `SessionPanel` enum, added `@StateObject` for `UsageAggregator`, wired Usage tab, added `refreshAll()` calls in `onAppear` and `onChange`
- `ClaudeConfigManager.xcodeproj/project.pbxproj` — Added all 7 new files to the Xcode project (PBXBuildFile, PBXFileReference, PBXGroup, PBXSourcesBuildPhase entries for both app and test targets)

## Key Decisions and Assumptions

1. **UsageAggregator takes T1 and T2 services directly** — initialized with `TranscriptScanner` and `RuntimeSessionDiscovery` references rather than owning its own scanners, avoiding duplicate scanning.

2. **Transcript cost data is unavailable** — Since `TranscriptMetadata` does not carry cost data (only token counts), `totalCostUsd` for transcript-derived session aggregates is set to 0. Only the current session (via status-line snapshot from T1) may have cost data.

3. **messageCount uses `lineCount`** — For transcript-derived sessions, `messageCount` maps to the transcript's `lineCount` since individual message parsing is only done for prompt history (not for per-session aggregation).

4. **Subagent transcripts excluded by default** — The `recentTranscripts` property from `TranscriptScanner` already filters to primary sessions only. Subagent transcripts are not double-counted in session-level totals.

5. **PromptHistoryEntry.from() maps "human" → "user"** — Transcript entries with type "human" are mapped to role "user" for display consistency. Non-message entry types (tool_use, tool_result, etc.) are excluded from prompt history.

6. **Model distribution bar chart** — Implemented as horizontal bar segments in SwiftUI rather than a full pie/stacked chart library, keeping dependencies minimal.

7. **SessionScopeView init changed** — The init now creates local `discovery` and `scanner` variables before wrapping them in `StateObject`, then passes both into the `UsageAggregator`. This ensures the aggregator references the same instances.

## Verification

**Cannot run xcodebuild in this environment** — The implementation sandbox is Linux-based without Xcode or Swift toolchain. The full test suite (`xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager -destination 'platform=macOS' -derivedDataPath /tmp/DerivedData -quiet`) must be run on Joe's Mac. Code has been manually reviewed for:
- Correct Swift syntax and type usage
- Proper `@MainActor` annotations on `UsageAggregator`
- Consistent use of `Identifiable`, `Codable`, `Equatable`, `Sendable` conformances
- No use of `Any` (used typed models throughout)
- No modification to existing public API

## Open Questions / Risks

1. **Xcode file references** — The project uses explicit file references (not folder references). All 7 new files have been added to `project.pbxproj` with unique IDs continuing the existing A1000…002C–0032 sequence.

2. **Token accumulation in TranscriptMetadata** — The T2 `extractMetadata` method currently takes the last-seen token count from each line, not a running sum. This means `totalTokensIn`/`totalTokensOut` on metadata may represent a single entry's usage rather than session totals. The aggregator faithfully uses whatever metadata provides, but usage numbers may be lower than expected for transcript-derived sessions.

3. **Prompt history performance** — Loading transcript content for up to 50 recent transcripts could be slow for large transcripts. Consider adding pagination or lazy loading in a future iteration.

## Recommended Next Packet

T3 (OTel Config Display) or move to the Resolver track (R1) depending on priority. T3 is optional and independent; the resolver track unlocks the Session UI pipeline.

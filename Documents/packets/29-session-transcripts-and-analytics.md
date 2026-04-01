# Packet 29 — Session Transcripts and Usage Analytics

## Context

Claude Code saves session transcripts as `.jsonl` files. This packet builds a full-featured transcript viewer and an analytics dashboard that aggregates usage across sessions — all from local files, no network required.

**Prerequisite: Packet 01 must be complete.**

## Prerequisites

- Packet 01 complete (pipeline wiring, build green)

## Deliverables

### 1. `.jsonl` transcript format

Before writing any code, find the `.jsonl` transcript files on the development machine at `~/.claude/projects/*/sessions/*.jsonl`. Read one to understand its schema. Typical entries include:
- User message turns (`role: "user"`)
- Assistant turns (`role: "assistant"`) with text and/or tool use blocks
- Tool result turns
- Usage blocks with `inputTokens` and `outputTokens`

Create `ClaudeConfigManager/Core/Models/TranscriptModels.swift` with types matching what you find:

```swift
struct TranscriptEntry: Codable {
    let role: String
    let content: TranscriptContent
    let usage: TranscriptUsage?
    let timestamp: Date?
}

// TranscriptContent and TranscriptUsage — define based on actual schema found
```

### 2. `TranscriptParser.swift`

Create `ClaudeConfigManager/Infrastructure/Parsers/TranscriptParser.swift`.

Parse a `.jsonl` file **lazily** — do not load the entire file into memory. Use `FileHandle` with line-by-line reading or `AsyncSequence`-based streaming.

```swift
struct TranscriptParser {
    /// Parse a .jsonl file, streaming entries one at a time.
    func parse(fileURL: URL) -> AsyncThrowingStream<TranscriptEntry, Error>

    /// Parse a summary without loading all content (for analytics).
    func parseSummary(fileURL: URL) -> TranscriptSummary
}

struct TranscriptSummary {
    let sessionId: String
    let projectId: String
    let turnCount: Int
    let inputTokens: Int
    let outputTokens: Int
    let estimatedCostUSD: Double   // at current API rates
    let startedAt: Date?
    let lastActivityAt: Date?
    let modelsUsed: [String: Int]  // model name → turn count
}
```

**Cost estimation**: Use published API pricing. Hardcode current rates as constants with a comment noting they require updating when Anthropic changes pricing. Do not make network calls.

### 3. Session Transcript Reader (L2)

Create `ClaudeConfigManager/Features/Session/TranscriptReaderView.swift`.

**Layout**: A `List` showing each turn in the transcript.

**Turn rendering**:
- **User turn**: right-aligned bubble with blue background, role badge "You"
- **Assistant turn**: left-aligned, white/secondary background, role badge "Claude"
- **Tool use**: indented block showing tool name (monospace, bold), input parameters (expandable), and result summary
- **Token usage**: shown per turn in a small secondary label at the bottom of each assistant turn

**Header**: Session ID, project name, total turns, total tokens, estimated cost, date.

**Jump-to-turn**: a `TextField` "Go to turn #" that scrolls to the specified turn index.

**Full-text search**: `TextField` with magnifying glass icon. Matches are highlighted in the rendered content. Navigation arrows (↑ ↓) move between matches.

**Export**: "Export summary" saves a human-readable Markdown summary of the session to a user-chosen location.

**Large file handling**: Since `.jsonl` files can be large, load turns incrementally: show the first 100 turns and load more as the user scrolls toward the end.

**Navigation**: Add a "Transcripts" item to the sidebar's Session section. It shows a list of sessions; tapping one opens `TranscriptReaderView`.

### 4. Usage Analytics Dashboard (L3)

Create `ClaudeConfigManager/Features/Session/UsageAnalyticsDashboardView.swift`.

**Scan all sessions**: on launch, scan `~/.claude/projects/*/sessions/*.jsonl` and parse summaries for all files. Cache summaries in memory (not on disk — recompute on next launch).

**Time window filter**: segmented control — Last 7 days / 30 days / 90 days / All time.

**Metrics cards** (header row):
- Total input tokens
- Total output tokens
- Total estimated cost (USD)
- Session count
- Project count

**Charts** (using Swift Charts framework — available on macOS 13+):
- **Line chart**: tokens per day over the selected time window (input and output as two series)
- **Bar chart**: top 5 projects by token usage
- **Donut chart**: model distribution (tokens by model)

**Top tools table**: The 5 most-invoked tool names across all sessions, with invocation count.

**Note**: all data is computed from local `.jsonl` files. No network access.

### 5. Tests

Create `ClaudeConfigManagerTests/Parsers/TranscriptParserTests.swift`:

Create a minimal fixture `.jsonl` file at `ClaudeConfigManagerTests/Fixtures/Transcripts/basic.jsonl` with 3–4 turns.

- **`testParsesSummaryCorrectly`** — parse the fixture → correct turn count, token counts
- **`testStreamingParsesAllEntries`** — async stream over the fixture → all entries received in order
- **`testCostEstimationIsPositive`** — fixture with non-zero tokens → estimated cost > 0
- **`testLargeFileDoesNotLoadEntirelyIntoMemory`** — this is documented as a design requirement; verify by checking that `parseSummary` does not read beyond the last entry

## Build and Test

```bash
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager \
  -destination 'platform=macOS' -quiet 2>&1 | tail -30
```

**Done criteria:**
- Transcript reader loads and displays session turns from real `.jsonl` files
- Large files stream incrementally without hanging
- Usage analytics dashboard shows metrics and charts computed from local data
- All existing tests pass, build has zero warnings

## Handover Note

Only create `Documents/29-handoff.md` if work deviated from the plan. Record what was completed, what was not (e.g. if Swift Charts was unavailable and a fallback was used), and recommended next step.

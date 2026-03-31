# Packet T4: Prompt & Usage Views

## Overview

This packet adds aggregate usage views computed from transcript and runtime session data. T4 depends on T1 (runtime snapshots) and T2 (transcript discovery) for its data sources. It provides per-session and cross-session usage summaries, model distribution analysis, and browsable prompt history.

All data is computed locally from transcripts and live session snapshots; no external API calls are made.

## Prerequisites

- T1 (Runtime Session Snapshot) completed
- T2 (Transcript Discovery and Browsing) completed
- `TranscriptMetadata` and `RuntimeSessionSnapshot` models available
- Async data aggregation patterns established

**Important notes on upstream model changes:**
- `RuntimeSessionSnapshot` (from T1) uses `totalInputTokens`/`totalOutputTokens` (not `totalTokensIn`/`totalTokensOut`), `modelId`/`modelDisplayName` (not plain `model` string), and `totalCostUsd`. The computation flow below should use the actual T1 field names.
- `TranscriptMetadata` (from T2) derives session identity from filename stems and path classification rules, and extracts model/tokens on a best-effort basis. All metadata fields except file-level ones (path, size, dates, lineCount) may be nil.
- Transcript content parsing is best-effort since the JSONL format is undocumented. `TranscriptEntry` preserves raw JSON as authoritative; typed fields are projections.

## Pre-read files

- `ClaudeConfigManager/Core/Models/` — existing model patterns
- `Documents/Specs/29-T1-runtime-session-snapshot.md`
- `Documents/Specs/30-T2-transcript-discovery.md`

## Required models and types

### 1. `UsageAggregate`

A summary of usage across a session or time range:

```swift
struct UsageAggregate: Identifiable, Codable {
    let id: String  // sessionId or time range identifier
    let sessionId: String?
    let startTime: Date?
    let endTime: Date?
    let totalTokensIn: Int
    let totalTokensOut: Int
    let totalTokens: Int { totalTokensIn + totalTokensOut }
    let totalCostUsd: Double
    let modelUsage: [ModelUsageBreakdown]  // Usage per model
    let messageCount: Int
    let toolUseCount: Int
    let duration: TimeInterval?

    var tokensPerMinute: Double? {
        guard let dur = duration, dur > 0 else { return nil }
        return Double(totalTokens) / (dur / 60)
    }

    var costPerKTokens: Double {
        guard totalTokens > 0 else { return 0 }
        return (totalCostUsd * 1000) / Double(totalTokens)
    }
}

struct ModelUsageBreakdown: Identifiable, Codable {
    let id: String  // model name
    let model: String
    let tokensIn: Int
    let tokensOut: Int
    let costUsd: Double
    let messageCount: Int?
}
```

### 2. `PromptHistoryEntry`

A simplified view of prompts for history browsing:

```swift
struct PromptHistoryEntry: Identifiable, Codable {
    let id: UUID
    let sessionId: String
    let timestamp: Date
    let role: String  // "user", "assistant", etc.
    let contentPreview: String  // First 200 chars
    let contentFull: String
    let tokensUsed: Int?

    var isUserPrompt: Bool {
        role == "user"
    }

    var isAssistantResponse: Bool {
        role == "assistant"
    }
}
```

### 3. `UsageComputationError`

Error types for usage aggregation:

```swift
enum UsageComputationError: LocalizedError {
    case noSessionsFound
    case invalidTokenCounts(sessionId: String, details: String)
    case failedToLoadTranscript(path: String)
    case internalError(details: String)

    var errorDescription: String? {
        switch self {
        case .noSessionsFound:
            return "No sessions or transcripts found to aggregate"
        case .invalidTokenCounts(let sessionId, let details):
            return "Invalid token counts for session \(sessionId): \(details)"
        case .failedToLoadTranscript(let path):
            return "Failed to load transcript for usage computation: \(path)"
        case .internalError(let details):
            return "Internal error computing usage: \(details)"
        }
    }
}
```

## Usage aggregation service

### `UsageAggregator`

A service for computing usage summaries:

```swift
@MainActor
final class UsageAggregator: ObservableObject {
    @Published var currentSessionUsage: UsageAggregate?
    @Published var recentSessionsUsage: [UsageAggregate] = []
    @Published var aggregateUsage: UsageAggregate?  // All sessions
    @Published var promptHistory: [PromptHistoryEntry] = []
    @Published var computationIssues: [UsageComputationError] = []

    private let transcriptScanner: TranscriptScanner
    private let runtimeDiscovery: RuntimeSessionDiscovery

    /// Initialize with discovery services.
    init(transcriptScanner: TranscriptScanner, runtimeDiscovery: RuntimeSessionDiscovery)

    /// Compute usage from current session snapshot.
    func computeCurrentSessionUsage() async

    /// Compute usage from recent transcripts (last 30 days).
    func computeRecentSessionsUsage() async

    /// Compute aggregate usage across all sessions.
    func computeAggregateUsage() async

    /// Load prompt history from recent transcripts.
    func loadPromptHistory(limit: Int = 100) async

    /// Refresh all usage data.
    func refreshAll() async
}
```

### Computation flow

#### Current session usage (from T1)

1. Get current snapshot from `RuntimeSessionSnapshot`
2. If snapshot exists and is not stale:
   - Extract `totalInputTokens`, `totalOutputTokens`, `totalCostUsd`, `modelId`, and `modelDisplayName`
   - Create `ModelUsageBreakdown` for current model
   - Create `UsageAggregate` with snapshot data
   - Set `currentSessionUsage`

#### Recent sessions usage (from T2)

1. Get all `TranscriptMetadata` from `TranscriptScanner.recentTranscripts`
2. Filter to primary session transcripts from the last 30 days
3. For each transcript:
   - Extract sessionId, model, total tokens, cost from metadata
   - If metadata is incomplete, optionally load transcript to fill in blanks
   - Create `UsageAggregate` for the session
4. Sort by modification date (most recent first)
5. Set `recentSessionsUsage`

#### Aggregate usage (all sessions)

1. Combine all `recentSessionsUsage` aggregates
2. Sum across all sessions:
   - `totalTokensIn`, `totalTokensOut`
   - `totalCostUsd`
   - `messageCount` (if available)
   - `toolUseCount` (if available)
3. Build combined `ModelUsageBreakdown` (per model across all sessions)
4. Compute `duration` as span from earliest start to latest end
5. Create aggregate `UsageAggregate`
6. Set `aggregateUsage`

#### Prompt history (from T2)

1. Load recent transcripts (last 7 days or up to 50 transcripts)
2. For each primary session transcript, parse all lines looking for messages:
   - Extract `role` (user, assistant, system)
   - Extract `content` and `timestamp`
   - Create `PromptHistoryEntry` with preview
3. Sort chronologically
4. Limit to most recent N entries (e.g., 100)
5. Set `promptHistory`

## Deliverables

### 1. Core models

- `UsageAggregate` struct with token counts, cost, model breakdown
- `ModelUsageBreakdown` for per-model usage
- `PromptHistoryEntry` for prompt browsing
- `UsageComputationError` enum for diagnostics
- All types must be `Identifiable` and `Codable`

### 2. Aggregation service

- `UsageAggregator` observable type
- Async methods for current session, recent sessions, and aggregate usage
- Prompt history loading with efficient transcript parsing
- Error collection without throwing

### 3. UI views

#### Usage Dashboard view

- Show `currentSessionUsage` (live or most recent session)
- Display `recentSessionsUsage` as a scrollable list of cards
  - Each card shows: session ID, model, duration, tokens, cost
  - Sorting: most recent first
- Display `aggregateUsage` summary
  - Total tokens, cost, duration, tokens/minute, cost/K-tokens
  - Model breakdown pie chart or stacked bar chart
  - Time range covered

#### Usage detail view

- Drilldown from a session card to see full details
- Show `ModelUsageBreakdown` for that session
- Display message count, tool use count if available
- Show cost breakdown and efficiency metrics

#### Prompt history view

- Scrollable list of `PromptHistoryEntry` items
- Show timestamp, role (user/assistant), preview
- Tap to expand and see full content
- Optional: search/filter by content or role
- Optional: export transcripts as text

### 4. Integration with Session view

- Add optional "Usage" tab to the Session scope view (after "Configuration")
- Or add a "Usage Dashboard" section below the live session snapshot
- Show current session usage inline
- Link to full usage dashboard view

### 5. Fixtures (optional, for testing)

**`Fixtures/runtime/usage/valid_aggregates/expected/session_aggregate.swift`:**
```swift
UsageAggregate(
    id: "sess-abc123",
    sessionId: "sess-abc123",
    startTime: Date(timeIntervalSince1970: 1743374400),
    endTime: Date(timeIntervalSince1970: 1743374100 + 900),
    totalTokensIn: 500,
    totalTokensOut: 200,
    totalCostUsd: 0.05,
    modelUsage: [
        ModelUsageBreakdown(
            id: "claude-opus-4-6",
            model: "claude-opus-4-6",
            tokensIn: 500,
            tokensOut: 200,
            costUsd: 0.05,
            messageCount: 4
        )
    ],
    messageCount: 4,
    toolUseCount: 0,
    duration: 900
)
```

**`Fixtures/runtime/usage/prompt_history/expected/entries.swift`:**
```swift
[
    PromptHistoryEntry(
        id: UUID(),
        sessionId: "sess-abc123",
        timestamp: Date(timeIntervalSince1970: 1743374400 + 15),
        role: "user",
        contentPreview: "Hello, world!",
        contentFull: "Hello, world!",
        tokensUsed: 5
    ),
    PromptHistoryEntry(
        id: UUID(),
        sessionId: "sess-abc123",
        timestamp: Date(timeIntervalSince1970: 1743374400 + 30),
        role: "assistant",
        contentPreview: "Hello! How can I help you today?",
        contentFull: "Hello! How can I help you today?",
        tokensUsed: 15
    )
]
```

## Tests

### Unit tests for `UsageAggregate`

- Create aggregate from session metadata
- Compute `tokensPerMinute` correctly
- Compute `costPerKTokens` correctly
- Handle missing token counts gracefully (zero, not crash)
- Combine multiple `ModelUsageBreakdown` items

### Unit tests for `PromptHistoryEntry`

- Create from transcript line data
- Extract `contentPreview` (first 200 chars)
- Preserve full `contentFull` for inspection
- Identify user vs. assistant prompts correctly

### Integration tests for `UsageAggregator`

- Compute current session usage from `RuntimeSessionSnapshot`
- Compute recent sessions usage from `TranscriptMetadata` (last 30 days)
- Exclude subagent transcripts from aggregate session totals unless explicitly included
- Skip stale or invalid sessions gracefully
- Aggregate across multiple sessions
- Sum tokens, cost, duration correctly
- Build per-model breakdown correctly
- Load prompt history from recent transcripts
- Sort prompt history chronologically
- Limit prompt history to most recent entries
- Preserve errors in `computationIssues` without throwing

### UI tests (optional)

- Usage dashboard displays all components (current, recent, aggregate)
- Model breakdown chart renders correctly
- Prompt history list is sorted chronologically
- Tapping a session card drills down to detail view
- Detail view shows full model breakdown and metrics

## Acceptance criteria

- [ ] `UsageAggregate` computes usage correctly from session data
- [ ] `ModelUsageBreakdown` breaks down usage per model
- [ ] `PromptHistoryEntry` extracts and preserves prompt content
- [ ] `UsageAggregator` computes current, recent, and aggregate usage
- [ ] Current session usage displays live data (or most recent if none active)
- [ ] Recent sessions list is chronologically sorted
- [ ] Aggregate usage dashboard shows totals and model breakdown
- [ ] Prompt history is loaded from recent transcripts
- [ ] Subagent transcripts are not double-counted in session-level totals by default
- [ ] Usage data is computed locally, no external API calls
- [ ] Errors are captured in `computationIssues` without crashes
- [ ] Usage tab integrates with Session scope view
- [ ] Full test suite passes

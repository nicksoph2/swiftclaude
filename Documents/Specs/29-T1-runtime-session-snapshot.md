# Packet T1: Runtime Session Snapshot

## Overview

This packet adds the ability to model and display live session state from running Claude Code instances. The session snapshot model mirrors the JSON payload that Claude Code pipes to the user's `statusLine` command via stdin. This provides a real-time window into active sessions including session ID, transcript path, model in use, context window usage, cost, and rate-limit state.

**Important architectural note:** Claude Code does NOT write snapshot files to disk (there is no `current.json` or `status.json`). The status-line JSON is delivered via stdin to a user-configured shell command. This packet therefore focuses on:

1. Defining Swift models that faithfully represent the documented status-line JSON schema
2. Providing a best-effort transcript-based discovery mechanism to extract session metadata from on-disk transcript files (complementing T2)
3. Laying groundwork for future integration if Claude Code adds a file-based or IPC-based session state API

This packet introduces the foundational models for the entire runtime observability track (T1–T4). It does not require parser/resolver completion and can begin once app shell and discovery foundations are stable.

## Prerequisites

- App shell exists (AppRouter, sidebar navigation)
- Discovery foundations exist (RootLocator, WorkspaceScanner, BookmarkStore)

## Pre-read files

- `ClaudeConfigManager/App/AppRouter.swift` — app navigation structure
- `ClaudeConfigManager/Core/Models/` — existing model patterns
- `ClaudeConfigManager/Infrastructure/Discovery/WorkspaceScanner.swift` — file discovery pattern
- `ClaudeConfigManager/Infrastructure/Discovery/RootLocator.swift` — root discovery pattern
- Claude Code status-line docs: https://code.claude.com/docs/en/statusline

## Status-line JSON schema (documented, March 2026)

Claude Code pipes the following snake_case JSON to the status-line command's stdin. All fields use snake_case. The `model` field is an object (not a plain string). Cost, context window, rate limits, workspace, and worktree data are nested objects.

```json
{
  "cwd": "/current/working/directory",
  "session_id": "abc123...",
  "transcript_path": "/path/to/transcript.jsonl",
  "version": "1.0.80",
  "model": {
    "id": "claude-opus-4-6",
    "display_name": "Opus"
  },
  "workspace": {
    "current_dir": "/current/working/directory",
    "project_dir": "/original/project/directory"
  },
  "output_style": {
    "name": "default"
  },
  "cost": {
    "total_cost_usd": 0.01234,
    "total_duration_ms": 45000,
    "total_api_duration_ms": 2300,
    "total_lines_added": 156,
    "total_lines_removed": 23
  },
  "context_window": {
    "total_input_tokens": 15234,
    "total_output_tokens": 4521,
    "context_window_size": 200000,
    "used_percentage": 8,
    "remaining_percentage": 92,
    "current_usage": {
      "input_tokens": 8500,
      "output_tokens": 1200,
      "cache_creation_input_tokens": 5000,
      "cache_read_input_tokens": 2000
    }
  },
  "exceeds_200k_tokens": false,
  "rate_limits": {
    "five_hour": {
      "used_percentage": 23.5,
      "resets_at": 1738425600
    },
    "seven_day": {
      "used_percentage": 41.2,
      "resets_at": 1738857600
    }
  },
  "vim": {
    "mode": "NORMAL"
  },
  "agent": {
    "name": "security-reviewer"
  },
  "worktree": {
    "name": "my-feature",
    "path": "/path/to/.claude/worktrees/my-feature",
    "branch": "worktree-my-feature",
    "original_cwd": "/path/to/project",
    "original_branch": "main"
  }
}
```

### Field presence rules

- **Always present**: `cwd`, `session_id`, `transcript_path`, `model`, `workspace`, `version`, `cost`, `context_window`
- **Conditionally present** (absent when not applicable, not null):
  - `vim` — only when vim mode is enabled
  - `agent` — only when running with `--agent` flag or agent settings
  - `worktree` — only during `--worktree` sessions; when present, `branch` and `original_branch` may be absent for hook-based worktrees
  - `rate_limits` — only for Claude.ai subscribers (Pro/Max) after first API response; each window (`five_hour`, `seven_day`) may be independently absent
- **May be null**:
  - `context_window.current_usage` — null before first API call
  - `context_window.used_percentage`, `context_window.remaining_percentage` — may be null early in session

## Required models and types

### 1. `StatusLinePayload`

A typed representation of the full status-line JSON schema. Uses `CodingKeys` to map snake_case JSON to Swift naming:

```swift
struct StatusLinePayload: Codable {
    let cwd: String
    let sessionId: String
    let transcriptPath: String
    let version: String?
    let model: StatusLineModel
    let workspace: StatusLineWorkspace
    let outputStyle: StatusLineOutputStyle?
    let cost: StatusLineCost
    let contextWindow: StatusLineContextWindow
    let exceeds200kTokens: Bool?
    let rateLimits: StatusLineRateLimits?
    let vim: StatusLineVim?
    let agent: StatusLineAgent?
    let worktree: StatusLineWorktree?

    enum CodingKeys: String, CodingKey {
        case cwd
        case sessionId = "session_id"
        case transcriptPath = "transcript_path"
        case version
        case model, workspace
        case outputStyle = "output_style"
        case cost
        case contextWindow = "context_window"
        case exceeds200kTokens = "exceeds_200k_tokens"
        case rateLimits = "rate_limits"
        case vim, agent, worktree
    }
}

struct StatusLineModel: Codable {
    let id: String
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
    }
}

struct StatusLineWorkspace: Codable {
    let currentDir: String
    let projectDir: String?

    enum CodingKeys: String, CodingKey {
        case currentDir = "current_dir"
        case projectDir = "project_dir"
    }
}

struct StatusLineOutputStyle: Codable {
    let name: String?
}

struct StatusLineCost: Codable {
    let totalCostUsd: Double?
    let totalDurationMs: Int?
    let totalApiDurationMs: Int?
    let totalLinesAdded: Int?
    let totalLinesRemoved: Int?

    enum CodingKeys: String, CodingKey {
        case totalCostUsd = "total_cost_usd"
        case totalDurationMs = "total_duration_ms"
        case totalApiDurationMs = "total_api_duration_ms"
        case totalLinesAdded = "total_lines_added"
        case totalLinesRemoved = "total_lines_removed"
    }
}

struct StatusLineContextWindow: Codable {
    let totalInputTokens: Int?
    let totalOutputTokens: Int?
    let contextWindowSize: Int?
    let usedPercentage: Double?
    let remainingPercentage: Double?
    let currentUsage: StatusLineCurrentUsage?

    enum CodingKeys: String, CodingKey {
        case totalInputTokens = "total_input_tokens"
        case totalOutputTokens = "total_output_tokens"
        case contextWindowSize = "context_window_size"
        case usedPercentage = "used_percentage"
        case remainingPercentage = "remaining_percentage"
        case currentUsage = "current_usage"
    }
}

struct StatusLineCurrentUsage: Codable {
    let inputTokens: Int?
    let outputTokens: Int?
    let cacheCreationInputTokens: Int?
    let cacheReadInputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
    }
}

struct StatusLineRateLimits: Codable {
    let fiveHour: StatusLineRateWindow?
    let sevenDay: StatusLineRateWindow?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
    }
}

struct StatusLineRateWindow: Codable {
    let usedPercentage: Double?
    let resetsAt: Int?  // Unix epoch seconds

    enum CodingKeys: String, CodingKey {
        case usedPercentage = "used_percentage"
        case resetsAt = "resets_at"
    }
}

struct StatusLineVim: Codable {
    let mode: String?  // "NORMAL" or "INSERT"
}

struct StatusLineAgent: Codable {
    let name: String?
}

struct StatusLineWorktree: Codable {
    let name: String?
    let path: String?
    let branch: String?  // absent for hook-based worktrees
    let originalCwd: String?
    let originalBranch: String?  // absent for hook-based worktrees

    enum CodingKeys: String, CodingKey {
        case name, path, branch
        case originalCwd = "original_cwd"
        case originalBranch = "original_branch"
    }
}
```

### 2. `RuntimeSessionSnapshot`

A simplified, app-facing projection of session state, derived from `StatusLinePayload` or from transcript metadata:

```swift
struct RuntimeSessionSnapshot: Identifiable, Codable {
    let id: String              // session_id
    let transcriptPath: String
    let modelId: String         // model.id
    let modelDisplayName: String // model.display_name
    let cwd: String
    let projectDir: String?
    let version: String?

    // Cost
    let totalCostUsd: Double?
    let totalDurationMs: Int?
    let totalLinesAdded: Int?
    let totalLinesRemoved: Int?

    // Context window
    let totalInputTokens: Int?
    let totalOutputTokens: Int?
    let contextWindowSize: Int?
    let usedPercentage: Double?

    // Rate limits (Pro/Max only, may be absent)
    let fiveHourUsedPercentage: Double?
    let fiveHourResetsAt: Int?   // Unix epoch seconds
    let sevenDayUsedPercentage: Double?
    let sevenDayResetsAt: Int?   // Unix epoch seconds

    let capturedAt: Date  // when this snapshot was created

    var isStale: Bool {
        Date.now.timeIntervalSince(capturedAt) > 30 * 60
    }

    var totalTokens: Int {
        (totalInputTokens ?? 0) + (totalOutputTokens ?? 0)
    }

    /// Create from a decoded StatusLinePayload
    init(from payload: StatusLinePayload, capturedAt: Date = .now) {
        self.id = payload.sessionId
        self.transcriptPath = payload.transcriptPath
        self.modelId = payload.model.id
        self.modelDisplayName = payload.model.displayName
        self.cwd = payload.cwd
        self.projectDir = payload.workspace.projectDir
        self.version = payload.version
        self.totalCostUsd = payload.cost.totalCostUsd
        self.totalDurationMs = payload.cost.totalDurationMs
        self.totalLinesAdded = payload.cost.totalLinesAdded
        self.totalLinesRemoved = payload.cost.totalLinesRemoved
        self.totalInputTokens = payload.contextWindow.totalInputTokens
        self.totalOutputTokens = payload.contextWindow.totalOutputTokens
        self.contextWindowSize = payload.contextWindow.contextWindowSize
        self.usedPercentage = payload.contextWindow.usedPercentage
        self.fiveHourUsedPercentage = payload.rateLimits?.fiveHour?.usedPercentage
        self.fiveHourResetsAt = payload.rateLimits?.fiveHour?.resetsAt
        self.sevenDayUsedPercentage = payload.rateLimits?.sevenDay?.usedPercentage
        self.sevenDayResetsAt = payload.rateLimits?.sevenDay?.resetsAt
        self.capturedAt = capturedAt
    }
}
```

### 3. `RuntimeSessionSnapshotError`

An enum for diagnostic issues:

```swift
enum RuntimeSessionSnapshotError: LocalizedError {
    case invalidJsonFormat(details: String)
    case missingRequiredField(fieldName: String)
    case transcriptNotFound(path: String)
    case fileAccessDenied(path: String)

    var errorDescription: String? {
        switch self {
        case .invalidJsonFormat(let details):
            return "Invalid status-line JSON: \(details)"
        case .missingRequiredField(let fieldName):
            return "Missing required field in status-line payload: \(fieldName)"
        case .transcriptNotFound(let path):
            return "Transcript file not found: \(path)"
        case .fileAccessDenied(let path):
            return "Access denied reading: \(path)"
        }
    }
}
```

## Data source strategy

### No file-based snapshot discovery

Claude Code does **not** write session snapshot files to disk. There is no `~/.claude/sessions/current.json` or `status.json`. The status-line JSON is delivered to a user-configured shell command via stdin and is not persisted by Claude Code.

### Best-effort transcript-based discovery

For the app to show session information without requiring the user to configure a custom status-line command, this packet should support best-effort session discovery by:

1. **Scanning primary session transcript files** recursively under `~/.claude/projects/` (leveraging T2 classification rules)
2. **Classifying only top-level `<session_id>.jsonl` files as primary sessions** for active-session inference and excluding `subagents/*.jsonl`
3. **Extracting metadata** from the most recently modified primary transcript (session ID from filename stem when needed, model from first/last lines, file modification time as proxy for activity)
4. **Marking data as "transcript-derived"** (not live) in the UI to distinguish from real-time status-line data

### Future: status-line command integration (optional stretch goal)

A future enhancement could register a custom status-line command that writes the JSON payload to a known file path, enabling true real-time snapshots. This is explicitly out of scope for the initial implementation but the models should be designed to support it.

### `RuntimeSessionDiscovery` type

```swift
@MainActor
final class RuntimeSessionDiscovery: ObservableObject {
    @Published var currentSession: RuntimeSessionSnapshot?
    @Published var lastUpdateTime: Date?
    @Published var discoveryIssues: [RuntimeSessionSnapshotError] = []
    @Published var dataSource: DataSource = .none

    enum DataSource {
        case none                    // No session data found
        case transcriptDerived       // Inferred from transcript files
        case statusLineSnapshot      // Future: from status-line command output
    }

    /// Scan primary session transcripts for the most recent session
    func discoverFromTranscripts() async

    /// Parse a StatusLinePayload JSON (for future status-line integration)
    func parseStatusLinePayload(_ jsonData: Data) -> Result<RuntimeSessionSnapshot, RuntimeSessionSnapshotError>
}
```

## Deliverables

### 1. Core models

- `StatusLinePayload` and all nested types faithfully representing the documented JSON schema
- `RuntimeSessionSnapshot` as the app-facing projection
- `RuntimeSessionSnapshotError` enum for diagnostics
- All types must be `Codable`; `RuntimeSessionSnapshot` must also be `Identifiable`

### 2. JSON decoding

- Snake_case JSON decoding with proper `CodingKeys`
- Handle absent fields (conditionally present) vs null fields correctly
- Decode rate limit `resets_at` as Unix epoch seconds (Int), not ISO 8601

### 3. Discovery service

- `RuntimeSessionDiscovery` observable type
- Transcript-based discovery: scan for the most recently modified primary session transcript, extract metadata
- `parseStatusLinePayload` method for decoding status-line JSON (enables future integration)
- Error collection and preservation

### 4. Session view integration

- Add a "Runtime Session" or "Live Session" card to the session scope view
- Display session ID, model (id and display name), context usage, cost, and rate-limit info
- Indicate data source (transcript-derived vs live)
- Show "no active session" when no data is available
- Show last update timestamp and staleness indicator

### 5. Fixtures

**`Fixtures/runtime/session_snapshot/valid_statusline/input/statusline.json`:**
```json
{
  "cwd": "/Users/alice/projects/myproject",
  "session_id": "sess-abc123def456",
  "transcript_path": "/Users/alice/.claude/projects/-Users-alice-projects-myproject/sess-abc123def456.jsonl",
  "version": "1.0.80",
  "model": {
    "id": "claude-opus-4-6",
    "display_name": "Opus"
  },
  "workspace": {
    "current_dir": "/Users/alice/projects/myproject",
    "project_dir": "/Users/alice/projects/myproject"
  },
  "output_style": {
    "name": "default"
  },
  "cost": {
    "total_cost_usd": 0.87,
    "total_duration_ms": 45000,
    "total_api_duration_ms": 2300,
    "total_lines_added": 156,
    "total_lines_removed": 23
  },
  "context_window": {
    "total_input_tokens": 45000,
    "total_output_tokens": 12000,
    "context_window_size": 200000,
    "used_percentage": 28.5,
    "remaining_percentage": 71.5,
    "current_usage": {
      "input_tokens": 8500,
      "output_tokens": 1200,
      "cache_creation_input_tokens": 5000,
      "cache_read_input_tokens": 2000
    }
  },
  "exceeds_200k_tokens": false,
  "rate_limits": {
    "five_hour": {
      "used_percentage": 23.5,
      "resets_at": 1738425600
    },
    "seven_day": {
      "used_percentage": 41.2,
      "resets_at": 1738857600
    }
  }
}
```

**`Fixtures/runtime/session_snapshot/partial_statusline/input/statusline.json`:**
```json
{
  "cwd": "/Users/bob/work",
  "session_id": "sess-xyz789",
  "transcript_path": "/Users/bob/.claude/projects/-Users-bob-work/sess-xyz789.jsonl",
  "model": {
    "id": "claude-sonnet-4-6",
    "display_name": "Sonnet"
  },
  "workspace": {
    "current_dir": "/Users/bob/work"
  },
  "cost": {
    "total_cost_usd": 0.0
  },
  "context_window": {
    "total_input_tokens": 0,
    "total_output_tokens": 0,
    "context_window_size": 200000,
    "current_usage": null
  }
}
```

**`Fixtures/runtime/session_snapshot/with_worktree/input/statusline.json`:**
```json
{
  "cwd": "/Users/alice/.claude/worktrees/my-feature",
  "session_id": "sess-wt-001",
  "transcript_path": "/Users/alice/.claude/projects/-Users-alice-projects-myproject/sess-wt-001.jsonl",
  "model": {
    "id": "claude-opus-4-6",
    "display_name": "Opus"
  },
  "workspace": {
    "current_dir": "/Users/alice/.claude/worktrees/my-feature",
    "project_dir": "/Users/alice/projects/myproject"
  },
  "cost": {
    "total_cost_usd": 0.15
  },
  "context_window": {
    "total_input_tokens": 5000,
    "total_output_tokens": 1500,
    "context_window_size": 200000,
    "used_percentage": 3.25,
    "remaining_percentage": 96.75
  },
  "worktree": {
    "name": "my-feature",
    "path": "/Users/alice/.claude/worktrees/my-feature",
    "branch": "worktree-my-feature",
    "original_cwd": "/Users/alice/projects/myproject",
    "original_branch": "main"
  }
}
```

## Tests

### Unit tests for `StatusLinePayload` decoding

- Decode full valid status-line JSON with all fields
- Decode partial JSON (no rate_limits, no vim, no agent, no worktree)
- Handle null `current_usage` correctly
- Handle absent optional objects (vim, agent, worktree) correctly
- Snake_case to Swift property mapping via CodingKeys
- Rate limit `resets_at` decoded as Int (Unix epoch seconds)

### Unit tests for `RuntimeSessionSnapshot`

- Create from `StatusLinePayload` with all fields
- Create from partial `StatusLinePayload`
- Computed properties: `totalTokens`, `isStale`
- `Identifiable` and `Codable` conformance

### Unit tests for `RuntimeSessionDiscovery`

- `parseStatusLinePayload` succeeds for valid JSON
- `parseStatusLinePayload` returns error for invalid JSON
- `parseStatusLinePayload` returns error for missing required fields (`session_id`, `transcript_path`, `model`)
- Transcript-based discovery finds most recently modified transcript
- Transcript-based discovery ignores subagent transcripts when inferring the active primary session
- "no active session" state when no transcripts are found

## Acceptance criteria

- [ ] `StatusLinePayload` faithfully represents the documented snake_case JSON schema
- [ ] `StatusLinePayload` decodes all nested objects (model, workspace, cost, context_window, rate_limits, vim, agent, worktree)
- [ ] `RuntimeSessionSnapshot` can be created from a `StatusLinePayload`
- [ ] `RuntimeSessionDiscovery` supports transcript-based discovery as best-effort
- [ ] Transcript-based discovery excludes subagent transcripts from active-session inference
- [ ] `RuntimeSessionDiscovery.parseStatusLinePayload` correctly decodes status-line JSON
- [ ] No references to `current.json` or `status.json` (these files do not exist)
- [ ] Rate limits use Unix epoch seconds (Int), not ISO 8601
- [ ] Live session info displays correctly in the session scope view
- [ ] Data source (transcript-derived vs live) is indicated in the UI
- [ ] "no active session" state is explicit, not a crash
- [ ] All error conditions are captured in `discoveryIssues` without throwing
- [ ] Full test suite passes

# Packet T2: Transcript Discovery and Browsing

## Overview

This packet adds the ability to discover, catalog, and browse Claude Code session transcripts stored under the Claude projects directory. Transcripts are stored as JSONL files and contain message, tool use, and event data from the session. This packet focuses on discovery, metadata extraction, path classification, and read-only viewing.

**Important: best-effort, not canonical.** The JSONL transcript format is **not formally documented** by Claude Code. The record schema used in this packet is derived from verified on-disk samples and may change without notice. The implementation must therefore:
- Treat the JSONL record schema as best-effort, not canonical
- Preserve raw JSON for every line as the authoritative representation
- Never reject a transcript file because individual lines don't match expected shapes
- Be resilient to schema evolution (new fields, changed field names, new record types)
- Use typed field extraction as convenience projections, not strict validation

T2 does not depend on T1 but complements it: T1 models live session state, T2 shows historical transcripts.

## Prerequisites

- App shell exists
- Discovery foundations exist (RootLocator, WorkspaceScanner, BookmarkStore)
- Async/await and file I/O patterns established

## Pre-read files

- `ClaudeConfigManager/Infrastructure/Discovery/WorkspaceScanner.swift` — file discovery pattern
- `ClaudeConfigManager/Core/Models/` — existing model patterns

## Transcript file locations

Transcripts are stored under the Claude projects directory. Based on verified on-disk samples, the current observed patterns are:

1. **Primary session transcripts**: `~/.claude/projects/<project_key>/<session_id>.jsonl`
2. **Subagent transcripts**: `~/.claude/projects/<project_key>/<session_id>/subagents/<agent_id>.jsonl`

The `<project_key>` is a Claude-created directory key derived from the project path. It is **not guaranteed to be a hash** or otherwise stable across versions.

**Note:** The exact directory structure and naming may vary across Claude Code versions. The implementation should:
- Use recursive scanning to find `.jsonl` files under `~/.claude/projects/`
- Classify transcripts by relative path rather than hard-coding a single directory depth
- Treat top-level `<session_id>.jsonl` files as primary session transcripts
- Treat `subagents/*.jsonl` files as child transcripts, not primary sessions
- Derive the session ID from the filename stem for primary session transcripts
- Derive the parent session ID from the containing directory for subagent transcripts
- Ignore or separately classify non-transcript artifacts such as `.meta.json`
- Fall back gracefully if the expected structure is different

## JSONL transcript format (best-effort, from on-disk samples)

Each line in a transcript JSONL file is a JSON object. Based on verified on-disk samples, records typically include a `type` field that indicates the record kind. However, the exact field names, nesting, and available types may differ.

**The implementation must not assume a fixed schema.** Instead, it should:
- Parse each line as a generic `[String: JSONValue]` dictionary
- Attempt to extract known fields (`type`, `role`, `content`, `timestamp`, etc.) where present
- Preserve the full raw JSON for every line
- Use the raw JSON as the authoritative representation; typed fields are convenience projections

### Common record patterns observed in on-disk samples

These are key-set patterns observed in local transcript files. They are **not guaranteed to be stable** and should be treated as heuristics:

```text
["content","operation","sessionId","timestamp","type"]
["operation","sessionId","timestamp","type"]
["cwd","entrypoint","gitBranch","isSidechain","message","parentUuid","permissionMode","promptId","sessionId","slug","timestamp","type","userType","uuid","version"]
["cwd","entrypoint","gitBranch","isSidechain","message","parentUuid","requestId","sessionId","slug","timestamp","type","userType","uuid","version"]
["cwd","entrypoint","gitBranch","isSidechain","message","parentUuid","promptId","sessionId","slug","sourceToolAssistantUUID","timestamp","toolUseResult","type","userType","uuid","version"]
```

**Key observations from on-disk samples:**
- The `type` field is usually present, but the observed values and surrounding structure vary more than a simple role/content schema
- Top-level `sessionId` is common and is often a better source than path-derived guesses when present
- Prompt/API correlation fields such as `promptId` and `requestId` may appear on records
- Message content is often nested under `message` and may itself contain structured content blocks
- Tool result data may appear in fields such as `toolUseResult`
- Usage/token data may appear in nested or top-level locations depending on record shape
- Model information may appear inside `message`, at the top level, or not at all
- Timestamps may or may not be present on every record
- New record types may appear in future versions

## Required models and types

### 1. `TranscriptEntry`

A single line from a transcript file. The raw JSON is always preserved:

```swift
struct TranscriptEntry: Identifiable, Codable {
    let id: UUID  // generated on load for UI purposes
    let lineNumber: Int  // 1-indexed line in the file
    let rawJson: [String: JSONValue]  // Full parsed JSON, authoritative representation
    let rawLine: String  // Original line text (for malformed lines)

    // Best-effort extracted fields (may be nil if format doesn't match expectations)
    let type: String?  // "human", "assistant", "tool_use", "tool_result", etc.
    let role: String?  // Extracted from nested message.role or top-level role
    let contentPreview: String?  // Best-effort text extraction for display
    let model: String?  // Extracted from message.model if present
    let timestamp: Date?  // If present
    let usage: TranscriptUsage?  // If present

    var displayText: String {
        // Render based on type and content, fallback to truncated raw JSON
    }
}

struct TranscriptUsage: Codable {
    let inputTokens: Int?
    let outputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}
```

### 2. `TranscriptMetadata`

Extracted metadata about a transcript file:

```swift
enum TranscriptKind: String, Codable {
    case primarySession
    case subagent
}

struct TranscriptMetadata: Identifiable, Codable {
    let id: String  // stable path-based identifier
    let sessionId: String?  // filename-stem session ID for primary transcripts; parent session ID for subagents
    let transcriptKind: TranscriptKind
    let agentId: String?  // filename-stem agent ID for subagent transcripts
    let projectKey: String?  // parent project directory key, not guaranteed hash
    let transcriptPath: String
    let fileSize: Int64
    let createdAt: Date?
    let modifiedAt: Date
    let lineCount: Int

    // Best-effort extracted from parsing first/last lines (may all be nil)
    let model: String?
    let totalTokensIn: Int?
    let totalTokensOut: Int?

    var isRecent: Bool {
        Date.now.timeIntervalSince(modifiedAt) < 7 * 24 * 60 * 60  // 7 days
    }
}
```

### 3. `TranscriptDiscoveryError`

Error types for transcript discovery:

```swift
enum TranscriptDiscoveryError: LocalizedError {
    case transcriptFileNotFound(path: String)
    case invalidJsonLine(path: String, lineNumber: Int, details: String)
    case fileAccessDenied(path: String)
    case unexpectedDirectoryStructure(path: String, details: String)

    var errorDescription: String? {
        switch self {
        case .transcriptFileNotFound(let path):
            return "Transcript file not found: \(path)"
        case .invalidJsonLine(let path, let line, let details):
            return "Invalid JSON on line \(line) of \(path): \(details)"
        case .fileAccessDenied(let path):
            return "Access denied reading transcript: \(path)"
        case .unexpectedDirectoryStructure(let path, let details):
            return "Unexpected transcript directory structure at \(path): \(details)"
        }
    }
}
```

## Discovery and scanning

### `TranscriptScanner`

A service for discovering and cataloging transcripts:

```swift
@MainActor
final class TranscriptScanner: ObservableObject {
    @Published var recentTranscripts: [TranscriptMetadata] = []
    @Published var discoveryIssues: [TranscriptDiscoveryError] = []

    private let rootLocator: RootLocator

    /// Scan Claude projects for primary-session and subagent transcripts.
    func scanTranscripts() async

    /// Load the full content (all lines) of a specific transcript.
    func loadTranscriptContent(path: String) async -> ([TranscriptEntry], [TranscriptDiscoveryError])

    /// Load only metadata (without reading all lines).
    func extractMetadata(path: String) async -> (TranscriptMetadata?, [TranscriptDiscoveryError])
}
```

### Discovery flow

1. Use `RootLocator` to find `~/.claude/`
2. Recursively scan `~/.claude/projects/` for `.jsonl` files
3. For each `.jsonl` file found:
   - Classify it as `primarySession` or `subagent` based on relative path
   - Extract file metadata (size, creation/modification dates)
   - Derive session ID from the filename stem for primary transcripts
   - Derive parent session ID from the containing directory for subagent transcripts
   - Derive agent ID from the filename stem for subagent transcripts
   - Derive project key from the first child directory under `~/.claude/projects/`
   - Count lines without fully parsing (for efficiency)
   - Parse first few lines to best-effort extract model name
   - Collect any errors without throwing
4. Exclude subagent transcripts from the primary-session list unless the UI explicitly asks for child transcripts
5. Sort by modification date (most recent first)
6. Publish `recentTranscripts`

### Content extraction heuristics

When parsing transcript lines, use these heuristics (not strict schema validation):

1. **Type detection**: Check for `type` field at top level
2. **Content extraction**:
   - If `message.content` exists and is an array, look for `{"type":"text","text":"..."}` blocks
   - If `message.content` is a string, use directly
   - If `content` exists at top level, use that
   - Fall back to truncated raw JSON
3. **Model extraction**: Check `message.model` or top-level `model`
4. **Usage extraction**: Check `message.usage` or top-level `usage`
5. **Role extraction**: Check `message.role` or top-level `role`

## Deliverables

### 1. Core models

- `TranscriptEntry` struct with raw JSON + best-effort extracted fields
- `TranscriptMetadata` struct for transcript file summaries
- `TranscriptDiscoveryError` enum for diagnostic issues
- Both metadata and entry types must be `Identifiable` and `Codable`

### 2. Discovery service

- `TranscriptScanner` observable type
- Async scan method that discovers transcripts without blocking UI
- Line-by-line JSONL parser that preserves all lines (including malformed)
- Best-effort metadata extraction from first/last lines
- Error collection (not throwing)

### 3. UI views

- List view showing `recentTranscripts` sorted by modification date
- Metadata display: session ID, model (if detected), file size, modification date
- Chronological sorting with "Recent" indicator for transcripts < 7 days old
- Tap/click to open transcript content viewer

### 4. Transcript content viewer

- Display `TranscriptEntry` items line-by-line
- Show line number and best-effort type for each entry
- Render `displayText` based on extracted content, with raw JSON fallback
- Toggle between "pretty" view and raw JSON view
- Allow scrolling and basic search (future enhancement)

### 5. Fixtures

**`Fixtures/runtime/transcripts/valid_transcript/input/transcript.jsonl`:**
```
{"type":"human","message":{"role":"user","content":[{"type":"text","text":"Hello, world!"}]}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Hello! How can I help you today?"}],"model":"claude-opus-4-6","usage":{"input_tokens":50,"output_tokens":15}}}
{"type":"tool_use","name":"Read","input":{"file_path":"/tmp/example.txt"}}
{"type":"tool_result","tool_use_id":"toolu_abc123","content":"Example file contents"}
```

**`Fixtures/runtime/transcripts/malformed_lines/input/transcript.jsonl`:**
```
{"type":"human","message":{"role":"user","content":[{"type":"text","text":"Valid line"}]}}
This is not JSON
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Response"}]}}
{incomplete json object
```

**`Fixtures/runtime/transcripts/unknown_types/input/transcript.jsonl`:**
```
{"type":"human","message":{"role":"user","content":[{"type":"text","text":"Hello"}]}}
{"type":"some_future_record_type","data":{"key":"value"}}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Hi"}]}}
```

**`Fixtures/runtime/transcripts/subagent_transcript/input/agent-abc123.jsonl`:**
```
{"sessionId":"sess-parent","timestamp":"2026-03-31T10:00:00Z","type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Subagent started"}]}}
{"sessionId":"sess-parent","timestamp":"2026-03-31T10:00:01Z","type":"assistant","toolUseResult":{"tool":"Read","status":"success"}}
```

## Tests

### Unit tests for `TranscriptEntry`

- Parse valid JSONL lines with nested message structure
- Extract content from `message.content` array of content blocks
- Extract model from `message.model`
- Extract usage from `message.usage`
- Handle unknown `type` values gracefully (preserve raw JSON, no crash)
- Malformed lines are captured with raw line text, not rejected

### Unit tests for `TranscriptMetadata`

- Derive session ID from filename stem for primary transcripts
- Derive parent session ID and agent ID for subagent transcripts
- Derive project key from parent project directory name
- Compute `isRecent` correctly (< 7 days based on modifiedAt)
- Handle missing model, token counts gracefully (all nil is valid)

### Integration tests for `TranscriptScanner`

- Discover transcripts by recursively scanning `~/.claude/projects/` for `.jsonl`
- Parse JSONL line-by-line without loading entire file into memory
- Best-effort extract model from first few lines
- Collect errors without throwing; preserve in `discoveryIssues`
- Most recent transcripts appear first in `recentTranscripts`
- Unknown record types are preserved, not rejected
- Classify subagent transcripts correctly and avoid double-counting them as primary sessions
- Empty transcript files produce metadata with lineCount 0

### UI tests (optional)

- List view displays `recentTranscripts` with metadata
- Content viewer displays `TranscriptEntry` items correctly
- Raw JSON toggle works

## Acceptance criteria

- [ ] `TranscriptMetadata` and `TranscriptEntry` are fully typed and `Identifiable`
- [ ] `TranscriptScanner` discovers transcripts under `~/.claude/projects/` using recursive `.jsonl` scanning
- [ ] Primary session transcripts and subagent transcripts are classified separately
- [ ] JSONL files are parsed line-by-line without loading entire file
- [ ] Raw JSON is preserved for every line as the authoritative representation
- [ ] Unknown record types and unexpected fields are preserved, not rejected
- [ ] Best-effort metadata extraction handles missing fields gracefully
- [ ] Recent transcripts are listed with chronological sorting
- [ ] Transcript content viewer supports both pretty and raw JSON views
- [ ] Malformed lines produce info-level issues, not crashes
- [ ] Missing or inaccessible transcripts show explicit error state
- [ ] All error conditions are captured in `discoveryIssues`
- [ ] Full test suite passes

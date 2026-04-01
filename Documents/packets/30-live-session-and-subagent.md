# Packet 30 — Live Session Binding and Subagent Visualization

## Context

This packet connects the app to a currently-running Claude Code instance to show live token consumption and active tool state, and adds a tree view of parent-subagent session hierarchies.

**Prerequisites: Packets 01 and 29 must be complete.**

## Prerequisites

- Packet 01 (pipeline wiring), Packet 29 (transcript parsing) complete

## Deliverables

### 1. Live session detection

Claude Code writes its current status to a location that can be monitored. Before implementing, investigate:
1. The status-line JSON payload — find where Claude Code writes its `statusLine` JSON output on disk. Check `~/.claude/` for any active session state files, lock files, or status JSON.
2. The active session transcript file — the current session's `.jsonl` file is written incrementally.

Document what you find. The implementation strategy depends on the available file mechanism.

**If a status JSON file exists**: Use `DispatchSource.makeFileSystemObjectSource` to watch the file for modifications.

**If only the transcript file is available**: Watch the transcript `.jsonl` file for new lines appended. Parse new lines as they appear.

Create `ClaudeConfigManager/Infrastructure/LiveSessionWatcher.swift`:

```swift
final class LiveSessionWatcher: ObservableObject {
    @Published private(set) var activeSession: LiveSessionState?
    @Published private(set) var isLive: Bool = false

    func start()
    func stop()
}

struct LiveSessionState {
    var inputTokensUsed: Int
    var outputTokensUsed: Int
    var contextWindowSize: Int
    var activeToolName: String?   // nil when no tool is executing
    var activeHookEvent: String?  // nil when no hook is executing
    var lastUpdated: Date
}
```

### 2. Live mode in Context Budget stage

Add a "Live" / "Estimated" toggle to the Context Budget stage toolbar.

**Estimated mode** (default): shows the static token budget from the resolved prompt assembly (as currently implemented).

**Live mode** (requires an active session):
- Shows `LiveSessionState.inputTokensUsed` and `outputTokensUsed` from `LiveSessionWatcher`
- The segmented bar chart animates as tokens are consumed
- A pulsing green dot indicates "Live" in the toolbar
- If no active session: "No active session detected" with a grey dot; the toggle is disabled

### 3. Active tool indicator in Tool Execution stage

When in live mode and `LiveSessionState.activeToolName` is non-nil:
- Highlight the matching tool card or permission gate in the Tool Execution stage
- Animate a "running" indicator (e.g. a spinning progress view next to the tool name)
- When the tool completes, the indicator fades

### 4. Subagent Session Visualization (L4)

Create `ClaudeConfigManager/Features/Session/SubagentTreeView.swift`.

Claude Code stores subagent transcripts at `~/.claude/projects/<key>/<session>/subagents/*.jsonl`. Find this path in the existing codebase or by inspecting the filesystem.

**Detection**: After loading a session transcript, check if a `subagents/` directory exists alongside it. If yes, load summaries for each subagent file.

**Tree rendering**:
- Root: parent session node (session ID, token usage, status)
- Children: each subagent session node (agent task summary from first user turn, token usage, status: complete/truncated)
- Lines connecting parent to subagents
- Each node tappable → opens the full `TranscriptReaderView` for that session

**Token summary**: parent + all subagent tokens summed, shown at the root node.

**Integration**: Add a "Subagents" expandable section at the bottom of `TranscriptReaderView` when subagent sessions are found.

### 5. Tests

- **`testLiveSessionWatcherDetectsNewLines`** — write lines to a temp `.jsonl` file → `LiveSessionWatcher` updates `activeSession` token counts
- **`testSubagentDirectoryScanned`** — create a temp subagent session file → `SubagentTreeView` model shows one child node
- **`testNoActiveSessionDisablesLiveToggle`** — no `.jsonl` file being actively written → `isLive` remains false

## Build and Test

```bash
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager \
  -destination 'platform=macOS' -quiet 2>&1 | tail -30
```

**Done criteria:**
- Live toggle appears in Context Budget stage
- When a Claude Code session is running, live token counts update in real time
- Active tool name highlights in the Tool Execution stage
- Subagent tree renders when subagent files exist
- All existing tests pass, build has zero warnings

**Note**: if Claude Code does not write a usable status file or the mechanism is undocumented, document exactly what was found and implement the transcript file watcher as the fallback. Create `Documents/30-handoff.md` even if work completed, noting the live session mechanism that was discovered.

## Handover Note

Create `Documents/30-handoff.md` regardless of outcome, documenting:
- Which file/mechanism was used for live session detection
- Whether real-time token count updates work
- Any limitations discovered (e.g. polling interval, file locking)

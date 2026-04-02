# Next Agent Handoff — Session Capture & What-If Simulation

> **Read `AGENT_CONTEXT.md` first.** It covers build commands, architecture rules,
> file structure, and the XcodeGen requirement. This document assumes you have read it.
>
> Then read this file in full before writing any code.
>
> Last updated: 3 April 2026.

---

## What has been built so far

This session added four new views to the existing Claude Config Manager app.
All consume `SessionProjection` via `ConfigurationPipeline` — no new infrastructure
was needed.

### 1. Config Grid (View A) — `Features/ConfigGrid/`

A function-grouped settings table with scope columns. Every resolved setting is
shown as a row, grouped by user intent (e.g. "Safety & Permissions", "Model &
Reasoning") rather than by file name. Each scope that defines the setting gets
a cell showing value and status (winner, overridden, contributor). Expandable
detail panels show merge method, resolution trace, and validation issues.

Files: `ConfigGridView.swift`, `ConfigGridViewModel.swift`,
`FunctionalGroupDefinitions.swift`.

### 2. Flow Strip (View C) — `Features/FlowStrip/`

A vertical phase-by-phase scroll showing how configuration becomes Claude's
behaviour. Six phases: Discovery, Settings, Instructions, Tools & MCP, Hooks,
and Prompt Assembly. Each phase has horizontal source cards with real content,
merge strips showing resolution method, and a context budget bar at the end.

Files: `FlowStripView.swift`, `FlowStripViewModel.swift`.

### 3. Session Timeline — `Features/FlowStrip/`

A chronological narrative of a Claude exchange, told in five acts:

1. **Environment** — configuration layers build up from least sticky (CLI, session)
   to most sticky (managed/enterprise policy). Each moment describes *what is
   being set* in plain English, not which file it came from.
2. **Ready State** — instructions assembled, MCP servers connected, permissions
   set, context budget calculated. This is everything Claude knows before you speak.
3. **Your Prompt** — pre-prompt hooks fire, then your message is combined with
   the system prompt, instructions, tool definitions, and history into an API request.
4. **The Exchange** — Claude receives the prompt, pre-tool-use hooks fire,
   tools execute, post-tool-use hooks fire, Claude replies.
5. **The Loop** — if the reply contains tool-use blocks, the cycle repeats.
   Stop hooks, notification hooks, sub-agent lifecycle hooks, and compaction
   hooks are shown where configured.

Every moment is expandable to show details: which settings contribute, which
scope won, what each hook does.

Files: `SessionTimelineView.swift`, `SessionTimelineViewModel.swift`.

### 4. Shared components — `Features/Shared/`

`ScopeChipView.swift`, `ValueCellView.swift`, `OriginBreadcrumbView.swift` —
reusable across all views.

### Sidebar and routing

All views are wired into `SidebarDestination` (cases: `.configGrid`, `.flowStrip`,
`.sessionTimeline`), `RootSplitView` (detail routing + keyboard shortcuts ⌘6, ⌘7,
⌘8), and the `ScopeStackSidebar` under the "Views" section.

### Pattern note: "Publishing changes from within view updates"

The codebase uses a deferred `Binding` pattern in `ScopeStackSidebar` to prevent
this SwiftUI error:

```swift
private var deferredSelection: Binding<SidebarDestination?> {
    Binding(
        get: { router.sidebarState.selection },
        set: { newValue in
            Task { @MainActor in
                router.sidebarState.selection = newValue
            }
        }
    )
}
```

All `.onAppear` calls that bind view models to the pipeline also use this pattern:

```swift
.onAppear {
    Task { @MainActor in
        viewModel.bind(to: pipeline)
    }
}
```

**You must follow this pattern for any new view that binds to
`ConfigurationPipeline` or mutates `@Published` state during view updates.**

---

## Your tasks

You have two features to build. They are complementary — the session capture
system provides the data that the what-if simulator operates on.

---

### Task 1: Session Capture and Replay

#### Goal

Allow the user to capture a snapshot of the resolved configuration at any point,
associate it with a transcript, and replay the exchange in the Session Timeline
view showing what actually happened.

#### What exists already

- `TranscriptParser` (`Infrastructure/Parsers/TranscriptParser.swift`) parses
  `.jsonl` session transcripts lazily via `AsyncThrowingStream`.
- `TranscriptListView` and `TranscriptReaderView` (`Features/Session/`) display
  transcripts.
- `ConfigurationSnapshotExporter` (`Infrastructure/Snapshot/`) exports the full
  resolved state.
- `ProfileStore` saves/loads named configuration profiles.
- `LiveSessionWatcher` (`Infrastructure/LiveSessionWatcher.swift`) monitors
  active sessions (currently stub-level).
- `SessionTimelineView` already has the five-act structure. Your job is to make
  Acts 3–5 show *real* data from a captured session, not just structural placeholders.

#### Implementation approach

1. **Session capture model.** Create `Core/Models/CapturedSession.swift`:

   ```swift
   struct CapturedSession: Codable, Identifiable {
       let id: UUID
       let capturedAt: Date
       let label: String                              // user-editable name
       let configSnapshot: ConfigurationSnapshotData  // resolved state at capture time
       let transcriptURL: URL?                        // optional .jsonl path
       let promptText: String?                        // the user's initial prompt
   }
   ```

   `ConfigurationSnapshotData` should be a Codable subset of `SessionProjection`
   — settings entries (key, effective value, winning scope), instruction block IDs,
   MCP server states, hook event types with handler summaries. It does *not* need
   to be the full `SessionProjection` — just enough to reconstruct the timeline.

2. **Capture store.** Create `Infrastructure/CapturedSessionStore.swift`.
   Persists `[CapturedSession]` as JSON in
   `~/Library/Application Support/ClaudeConfigManager/captured-sessions/`.
   Use `AtomicFileWriter` for all writes. Provide `save(_:)`, `load() -> [CapturedSession]`,
   `delete(id:)`.

3. **Capture action.** Add a "Capture Current State" button to the Session
   Timeline toolbar and to the Dashboard. When tapped:
   - Serialise the current `SessionProjection` into `ConfigurationSnapshotData`.
   - Optionally let the user paste a prompt or pick a transcript `.jsonl`.
   - Save via `CapturedSessionStore`.

4. **Replay mode in Session Timeline.** When a `CapturedSession` is selected
   (via a picker in the timeline toolbar), the view switches to replay mode:
   - Acts 1–2 render from the *captured* snapshot, not the live pipeline.
   - Act 3 shows the captured prompt text.
   - Acts 3–5 render real events parsed from the transcript:
     - Each user turn, assistant turn, and tool-use block becomes a `TimelineMoment`.
     - Hook events that *would have* fired (based on the captured hook config)
       are shown interleaved at the correct points.
   - A playback scrubber (horizontal slider or stepper) lets the user walk
     through the transcript turn by turn.

5. **Transcript → timeline mapping.** In `SessionTimelineViewModel`, add:

   ```swift
   func loadReplay(session: CapturedSession) async
   ```

   This method:
   - Parses the transcript via `TranscriptParser`.
   - Maps each entry to the appropriate act (user messages → Act 3, assistant
     responses → Act 4, tool results → Act 4, agentic continuation → Act 5).
   - Inserts hook moments at the correct positions based on the captured hook config.
   - Annotates each moment with token counts from the transcript's usage blocks.

#### Files to create

```
Core/Models/CapturedSession.swift
Infrastructure/CapturedSessionStore.swift
```

#### Files to modify

```
Features/FlowStrip/SessionTimelineView.swift      — add toolbar picker, replay mode
Features/FlowStrip/SessionTimelineViewModel.swift  — add loadReplay(), transcript mapping
Features/Dashboard/ConfigurationDashboardView.swift — add capture button
App/SidebarDestination.swift                        — no change needed (already wired)
```

---

### Task 2: What-If Configuration Simulator

#### Goal

Let the user alter any setting, insert a prompt, and immediately see how the
resolved state, permissions, hooks, and context budget would change — without
writing anything to disk.

#### What exists already

- `PermissionRuleSimulator` (`Infrastructure/PermissionRuleSimulator.swift`)
  evaluates a tool invocation against the resolved permission rules. It is pure
  (no I/O) and returns a `SimulationResult` with matched rule, scope, hooks
  triggered, and evaluation trace. See `Documents/packets/25-what-if-inspector.md`.
- `PipelinePreviewTypes` (`Infrastructure/PipelinePreviewTypes.swift`) supports
  in-memory pipeline re-resolution for pre-save previews.
- `WhatIfInspectorView` and `SettingsChangeImpactView` (`Features/WhatIf/`)
  exist but may be stubs — inspect them before starting.

#### Implementation approach

1. **What-If state model.** Create a `WhatIfScenario` that represents a set of
   hypothetical changes layered on top of the current `SessionProjection`:

   ```swift
   struct WhatIfScenario: Identifiable {
       let id: UUID
       var label: String
       var settingOverrides: [String: JSONValue]      // keyPath → new value
       var promptText: String                          // hypothetical user prompt
       var disabledMcpServers: Set<String>             // serverIDs to suppress
       var additionalHookHandlers: [HookOverride]      // extra hooks to simulate
   }
   ```

2. **In-memory re-resolution.** The core of the feature. Given the current
   pipeline state + a `WhatIfScenario`, produce a *modified* `SessionProjection`
   without touching disk:

   - Clone the current resolver inputs.
   - Apply `settingOverrides` as a synthetic highest-precedence source.
   - Re-run the settings resolver, MCP resolver, and hook resolver.
   - Build a new `SessionProjection` via `SessionProjectionBuilder`.
   - Diff the original and modified projections to produce a change summary.

   Check `PipelinePreviewTypes.swift` — if it already does partial re-resolution,
   extend it. If not, create `Infrastructure/WhatIfResolver.swift`.

3. **What-If view.** Extend or rebuild `Features/WhatIf/WhatIfInspectorView.swift`:

   - Left panel: scenario editor. A form where the user can:
     - Override any setting (searchable key picker + value editor).
     - Type a hypothetical prompt.
     - Toggle MCP servers on/off.
     - Add/remove hook handlers.
   - Right panel: impact preview. Shows:
     - **Settings diff** — which keys changed, old vs new, which scope was affected.
     - **Permission simulation** — if a prompt was entered, run
       `PermissionRuleSimulator.evaluate()` against the modified projection and
       show the result (allowed/denied/ask, matched rule, evaluation trace).
     - **Hook timeline** — which hooks *would* fire for the prompt, in order,
       with the modified hook config.
     - **Budget impact** — how the context budget changes (new instruction tokens,
       new tool definitions, etc.).
   - The impact preview should update live as the user types.

4. **Integration with Session Timeline.** Add a "What If" toggle to the Session
   Timeline toolbar. When active:
   - The timeline re-renders using the modified projection from the active scenario.
   - Changed moments are highlighted (e.g. amber border or "modified" badge).
   - The user can see "if I changed this setting, how would the exchange differ?"

5. **Scenario persistence.** Optionally save scenarios to
   `~/Library/Application Support/ClaudeConfigManager/what-if-scenarios/`.
   This is lower priority — in-memory is fine for v1.

#### Files to create

```
Core/Models/WhatIfScenario.swift
Infrastructure/WhatIfResolver.swift  (unless PipelinePreviewTypes is sufficient)
```

#### Files to modify

```
Features/WhatIf/WhatIfInspectorView.swift
Features/WhatIf/SettingsChangeImpactView.swift
Features/FlowStrip/SessionTimelineView.swift      — what-if toggle
Features/FlowStrip/SessionTimelineViewModel.swift  — accept modified projection
```

---

## Architectural guidance

### Do not break existing views

The Flow Strip, Config Grid, and Session Timeline are working and tested via
build. Do not change their data models without verifying that all three still
compile and render correctly.

### Follow the weak-pipeline Combine pattern

Every view model holds a `weak var pipeline: ConfigurationPipeline?` and
observes via Combine. The what-if resolver should produce a *separate*
`SessionProjection` — do not mutate the pipeline's published projection.
Instead, the what-if view model should hold its own `@Published var
modifiedProjection: SessionProjection?` and the views should read from that
when in what-if mode.

### Use existing resolver infrastructure

Do not rewrite resolvers. The existing `SettingsResolver`, `MCPResolver`,
`HookResolver`, `InstructionResolver`, and `SessionProjectionBuilder` are all
pure functions that accept inputs and return outputs. The what-if system should:
- Build modified inputs (with overrides applied).
- Call the existing resolvers with those inputs.
- Build a new projection from the results.

### Transcript parsing is lazy

`TranscriptParser.parse(fileURL:)` returns `AsyncThrowingStream`. For replay,
you'll want to collect entries into an array — but be mindful of very long
sessions. Consider a reasonable cap (e.g. 500 turns) with a "load more" option.

### XcodeGen

After creating new `.swift` files, the user must run `xcodegen generate` from
`ClaudeConfigManager/`. You cannot run it — just note that it's needed. All new
files under `Features/` and `Infrastructure/` are auto-discovered by the
existing `project.yml` source rules.

### Testing

- `PermissionRuleSimulator` already has tests in
  `ClaudeConfigManagerTests/Infrastructure/`. Follow the same pattern for the
  what-if resolver.
- Captured session serialisation should be tested with round-trip encode/decode.
- The transcript → timeline mapping should have tests with fixture `.jsonl` files.

---

## Build order recommendation

1. `CapturedSession` model and `CapturedSessionStore` — small, testable, no UI.
2. What-If scenario model and resolver — builds on existing resolver infra.
3. Session capture UI (toolbar button, save flow).
4. What-If inspector view (scenario editor + impact preview).
5. Transcript → timeline replay mapping.
6. Session Timeline replay mode (scrubber, real data in Acts 3–5).
7. Session Timeline what-if toggle.
8. Test pass.

---

## Reference documents

| Document | Purpose |
|----------|---------|
| `Documents/AGENT_CONTEXT.md` | Master briefing — architecture, rules, file map |
| `Documents/UI-REDESIGN-SPEC.md` | Spec for the views built in this session |
| `Documents/packets/25-what-if-inspector.md` | Original what-if packet spec |
| `Documents/packets/29-session-transcripts-and-analytics.md` | Transcript parsing spec |
| `Documents/packets/30-live-session-and-subagent.md` | Live session watcher spec |
| `Documents/packets/27-snapshots-and-profiles.md` | Snapshot/profile infra |

---

## Summary of what the owner wants

In the owner's words: the app should let you "log traffic and then review
outcomes and then play them back." The Session Timeline is a teaching and
diagnostic tool — it should show not just what *would* happen based on config,
but what *did* happen in a real session. The what-if mode lets you ask "if I
changed this setting, what would be different?" and see the answer immediately,
without leaving the app or editing files.

The goal is to make Claude's configuration and behaviour **visible and
explorable** — to expose the flow of information at every level of detail, from
a glance summary to the full resolution trace.

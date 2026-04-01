# Packet 11 — Unified Pipeline Diagram: Static Layout

## Context

The current `TreePipelineOverviewStrip` is a simple horizontal strip placeholder. This packet replaces it with the **Unified Interactive Pipeline Diagram** — the app's intended primary view: a `Canvas`-backed or custom `Layout`-driven view showing all eight pipeline stages as connected node cards in a single, non-scrolling layout. This is the most visually significant change in the app. The layout and static rendering are built here; interactive zoom is added in Packet 12.

This packet can be built with **mock/stub data** before the resolver is fully producing real data. The animated interactions and real data wiring are subsequent packets. Start with a compelling static visual.

**Prerequisite: Packet 01 must be complete. The diagram does not depend on Packets 03–10 and can be built in parallel.**

## Prerequisites

- Packet 01 complete (build green, tests passing)

## Deliverables

### 1. Read the existing tree view code

Read `ClaudeConfigManager/Features/Tree/TreePipelineView.swift`, `TreePipelineViewModel.swift`, and `TreePipelineOverviewStrip.swift`. Understand how the tree view is currently structured and how the overview strip is used. The existing eight stage detail views (Discovery, Parsing, Resolution, Prompt Assembly, etc.) must remain unchanged — this packet only replaces the overview strip.

Also read `ClaudeConfigManager/Core/Models/TreePipelineModels.swift` to understand `PipelineStage`, `StageHealth`, and related types.

### 2. Node layout model

Create `ClaudeConfigManager/Features/Tree/DiagramLayout.swift`.

Define the fixed layout positions for eight nodes arranged in two rows (four per row) that fit within a standard 13" MacBook content area (approximately 900×600 pt usable area):

```
Row 1: Discovery → Parsing → Resolution → Prompt Assembly
                                          ↓
Row 2: Context Budget ← MCP Servers ← Hooks Lifecycle ← Tool Execution
```

The arrows connect in a U-shape: left-to-right on row 1, then down, then right-to-left on row 2.

Store node positions as `CGPoint` values relative to a coordinate space. Store arrow paths as `Path` values connecting node anchor points. This is a fixed layout — not Auto Layout, not geometry-driven.

### 3. `PipelineDiagramView.swift`

Create `ClaudeConfigManager/Features/Tree/PipelineDiagramView.swift`.

**Node cards**: Each stage is rendered as a `RoundedRectangle` card (approximately 160×90 pt) containing:
- SF Symbol icon (use `PipelineStage.icon` from the existing models) — 20pt
- Stage name — bold, 13pt
- Health indicator dot — 8pt circle, coloured by `StageHealth`:
  - `.healthy` → green
  - `.warnings(n)` → amber, with count label
  - `.errors(n)` → red, with count label
  - `.noData` → grey
- Key metric label — secondary text, 11pt (e.g. "9 files", "3 issues", "18K tokens", "3 servers")
- Scope contribution dots — a horizontal row of 6pt circles, one per active scope, coloured by `ScopeColorScheme`. Only show scopes that contribute data at this stage.

**Arrows**: Drawn using `Path` in a `Canvas` layer behind the node cards. Arrow colour: `.secondary`. Arrowhead: a small filled triangle at the destination end. The arrow between nodes curves slightly (use a `QuadCurve` or `BezierCurve`) to avoid looking mechanical.

**Scroll/fit**: The entire diagram fits within a `GeometryReader`; scale down proportionally if the container is narrower than the design width. Do not allow the diagram to scroll — it must fit.

**Card background**: Use `.background(.regularMaterial)` for cards. Selected/hovered card: `.background(.regularMaterial)` with a coloured border in the stage's health colour. Hover effect: subtle shadow lift.

### 4. Wire into `TreePipelineView`

In `TreePipelineView.swift`, replace the `TreePipelineOverviewStrip` with `PipelineDiagramView`. The existing stage detail content (the eight DisclosureGroups below it) should remain unchanged for now — they are the "zoomed in" destination that Packet 12 will wire up.

Pass the `TreePipelineViewModel` data to the diagram. Initially wire up health and metric data from the view model's existing published properties. If some stage data is not yet available from the view model, show `.noData` health — do not crash.

### 5. Mock data for development

Add a `static var preview: [PipelineStageStatus]` computed property or similar that provides realistic-looking mock data for the eight stages. Use this in SwiftUI `#Preview` blocks for fast iteration without needing real config files.

### 6. `PipelineDiagramViewTests` — Preview compilation

Add a test that verifies the `PipelineDiagramView` preview compiles and renders without crashing using the mock data. Use `XCTest` + SwiftUI preview rendering if available, or at minimum a `@MainActor` test that instantiates the view with mock data.

## Build and Test

```bash
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager \
  -destination 'platform=macOS' -quiet 2>&1 | tail -30
```

**Done criteria:**
- The app launches and the Pipeline tab shows the eight-node diagram instead of the overview strip
- All eight nodes are visible without scrolling on a standard window size
- Arrows connect the nodes in the correct U-shape pattern
- Health dots show green when data is available, grey when absent
- Scope contribution dots appear for scopes that have data
- All existing tests pass
- Build has zero warnings

## Handover Note

Only create `Documents/11-handoff.md` if work deviated from the plan. Record what was completed, what was not, any layout difficulties, and recommended next step for Packet 12 (animated zoom).

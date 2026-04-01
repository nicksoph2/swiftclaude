# Packet 12 — Diagram: Animated Node Zoom and Simplified Mode

## Context

Packet 11 built the static eight-node pipeline diagram. This packet adds two interactions that bring it to life:

1. **Animated node zoom** — tapping a stage node expands it to fill the detail area while the remaining nodes compress into a breadcrumb navigation strip, using `matchedGeometryEffect`.
2. **Simplified 3-stage mode** — a toolbar toggle collapses the eight nodes into three composite "plain English" nodes for new users.

**Prerequisite: Packet 11 must be complete.**

## Prerequisites

- Packet 11 complete (static diagram rendering in the app)

## Deliverables

### 1. Read the existing stage detail views

Read `ClaudeConfigManager/Features/Tree/TreePipelineView.swift` to understand how the eight stage detail views (Discovery, Parsing, Resolution, Prompt Assembly, Tool Execution, Hooks Lifecycle, MCP Servers, Context Budget) are currently structured. These views must become the **zoom-in destinations** — their content is unchanged; only how they appear in the navigation changes.

### 2. Navigation state

In `TreePipelineViewModel`, add:

```swift
@Published var selectedStage: PipelineStage? = nil
```

When `selectedStage` is nil, the full eight-node diagram is shown. When a stage is selected, the diagram transitions to the zoomed view.

### 3. Zoomed layout: breadcrumb strip + detail area

When a node is tapped:

**Breadcrumb strip** — the remaining seven nodes compress into a horizontal strip pinned above the detail area. Each node in the strip shows only the SF Symbol icon and a health dot (no labels, no metrics). The selected stage is highlighted with its health colour border. The strip scrolls horizontally if needed.

**Detail area** — the selected stage's existing detail view fills the remaining space below the breadcrumb strip. This is the same view that was previously visible in the scrollable `DisclosureGroup` — now it has the full content area.

**Back navigation** — tapping the selected stage in the breadcrumb strip deselects it, collapsing back to the full diagram. A "← Pipeline" back button also appears at the leading edge of the breadcrumb strip.

### 4. `matchedGeometryEffect` animation

Use `@Namespace` and `matchedGeometryEffect` to animate the transition:

- The tapped node card animates from its diagram position to fill the header/title area of the detail view
- The remaining cards animate from their diagram positions to their breadcrumb positions
- The detail view content fades in after the node has expanded
- Reverse animation plays on back navigation

Use `withAnimation(.spring(response: 0.4, dampingFraction: 0.8))`.

Key: every node card must have a consistent `matchedGeometryEffect(id: stage, in: namespace)` identifier in both the diagram layout and the breadcrumb strip.

### 5. Keyboard and accessibility

- The selected stage in the breadcrumb strip has an accessibility label: "[Stage name] stage, currently showing detail. Tap to return to overview."
- Each breadcrumb node has an accessibility label: "[Stage name] stage. [Health description]. Tap to switch."
- Pressing Escape when a stage is selected deselects it (returns to overview)

### 6. Simplified 3-Stage Mode

Add a toolbar button labelled "Overview" / "Advanced" (or a segmented control) that toggles between simplified and full modes.

**Simplified mode** shows three composite node cards:

| Composite node | Contains | Label | Icon |
|---|---|---|---|
| "Your Files" | Discovery + Parsing | Count of files + parse issues | `doc.on.doc` |
| "The Rules" | Resolution + Tool Execution + Hooks | Conflict count + rule count | `list.bullet.clipboard` |
| "What Claude Sees" | Prompt Assembly + MCP + Context Budget | Token count + server count | `cpu` |

Tapping a composite node in simplified mode zooms in to show **all its constituent stages** as a mini-diagram within the detail area — not jumping directly to one stage. The user can then tap an individual constituent node to zoom into that stage's full detail.

Store the mode preference in `@AppStorage("diagramMode")` with values `"simplified"` and `"advanced"`. Default: `"simplified"` for new users (check `AppStorage("hasActivatedAdvancedMode")`). Once the user activates advanced mode, it stays.

### 7. Tests

Add to `ClaudeConfigManagerTests/`:
- **`testSelectingStageUpdatesSelectedStage`** — set `viewModel.selectedStage = .parsing` → breadcrumb strip state is correct
- **`testDeselectingStageReturnsToNil`** — set then clear `selectedStage` → diagram state returns to overview
- **`testSimplifiedModeDefaultsForNewUser`** — fresh `AppStorage` → mode is `.simplified`

## Build and Test

```bash
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager \
  -destination 'platform=macOS' -quiet 2>&1 | tail -30
```

**Done criteria:**
- Tapping a node in the diagram animates the zoom with `matchedGeometryEffect`
- The breadcrumb strip shows all eight stages during zoom
- Back navigation returns to the full diagram
- Simplified mode shows three composite nodes
- Tapping a composite node reveals its constituent stages
- Mode preference persists across launches
- All existing tests pass
- Build has zero warnings

## Handover Note

Only create `Documents/12-handoff.md` if work deviated from the plan. Record what was completed, what was not, any `matchedGeometryEffect` issues, and recommended next step.

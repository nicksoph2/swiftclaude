# Packet 13 — Diagram: Navigable Arrows and Health Propagation

## Context

Packets 11 and 12 built the diagram and its zoom interaction. This packet adds the two features that make the diagram a **teaching tool** rather than just a pretty overview: tappable cross-stage arrows that explain what flows between stages, and health propagation that visually traces validation errors downstream along the arrows.

**Prerequisite: Packet 12 must be complete.**

## Prerequisites

- Packet 12 complete (animated zoom working)

## Deliverables

### 1. Tappable arrows

Each arrow in the diagram (there are ~eight edges in the U-shape pipeline) must be tappable. Make the tap target larger than the visual path — use an invisible wide stroke (e.g. 20pt) over the arrow path as the hit area, with the visible 2pt stroke on top.

When an arrow is tapped, present a **flow panel** as a sheet (on narrow windows) or popover (on wide windows). The panel has a title "What flows here" and explains what data travels between the two connected stages.

Write the explanation text for all eight edges:

| Edge | Explanation |
|---|---|
| Discovery → Parsing | "The raw files found on disk are handed to parsers. Each discovered file is parsed into structured data — settings keys, hook configurations, MCP server definitions, or instruction text." |
| Parsing → Resolution | "Parsed key-value pairs from every scope's files are collected and passed to the resolver, which determines a single winning value for each key." |
| Resolution → Prompt Assembly | "Resolved settings govern how Claude's system prompt, tools list, and instruction stack are assembled from the CLAUDE.md files found during discovery." |
| Prompt Assembly → Tool Execution | "The assembled prompt determines which tools Claude is given access to. The tool execution gate then applies permission rules to decide which tools Claude may actually use." |
| Tool Execution → Hooks Lifecycle | "When Claude calls a tool, hooks that match that tool invocation are triggered. Hook execution is part of the tool call lifecycle." |
| Hooks Lifecycle → MCP Servers | "Hooks can invoke MCP server tools. The MCP server landscape determines which external tools are available to hooks as well as to Claude directly." |
| MCP Servers → Context Budget | "Each active MCP server's tool list contributes to the total tool count and consumes a portion of the available context budget." |
| Context Budget → (output) | "The final assembled context — system prompt, instructions, tools, and conversation history — is bounded by the context budget. Anything that would exceed the budget is truncated or summarised." |

Each flow panel also shows dynamic data where available:
- File/key counts relevant to that edge (e.g. "9 files passed to parsers")
- Link to the source stage: "View Discovery stage →"
- Link to the destination stage: "View Parsing stage →"

### 2. Health propagation along edges

When a stage has validation errors or warnings (from the pipeline's parse issues and semantic issues), propagate warning indicators along all **downstream** arrows.

**Visual**: A small amber or red dot on the arrow path (at its midpoint), with a count badge if multiple issues propagate through that edge. Error (red) takes precedence over warning (amber).

**Propagation rule**: An issue at stage S propagates to all arrows whose source is S or whose source is downstream of S. For example, an error in Parsing propagates along all arrows from Parsing through to Context Budget.

**Tap the propagated warning dot**: Opens a mini-panel with:
- "1 upstream issue is affecting this stage"
- A list of the issue titles (from the pipeline's issue array)
- "Show source" button: navigates to the source stage (zooms into it)

**No propagation if no issues**: arrows render normally with no dots.

### 3. Sub-process expansion toggle (Z5)

Within the zoomed Resolution stage view, add a "Show sub-processes" toggle button. When active, it renders an intermediate diagram within the detail area showing the three merge method paths as parallel vertical lanes:

```
Override lane    |   AppendUnique lane   |   DeepMerge lane
(settings where  |   (permission arrays, |   (env object,
highest scope    |    hook arrays)       |    sandbox object)
wins)            |                       |
key1 ─────────► |   key3 ────────────► |   key5 ──────────►
key2 ─────────► |   key4 ────────────► |   key6 ──────────►
```

Colour each lane using the merge method's icon colour (use a consistent palette). Show 3-5 example keys in each lane drawn from the real resolved data.

Toggle state stored in `@SceneStorage("resolutionSubProcessExpanded")`.

### 4. Tests

- **`testFlowPanelContentForEachEdge`** — verify the flow panel text is non-empty for all eight edges
- **`testHealthPropagationFromParsing`** — inject a mock pipeline state with a parsing error → downstream edges have propagated warning indicator
- **`testNoHealthDotWhenNoIssues`** — clean pipeline state → no warning dots on any arrow

## Build and Test

```bash
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager \
  -destination 'platform=macOS' -quiet 2>&1 | tail -30
```

**Done criteria:**
- Tapping each arrow opens a flow panel with the correct explanation text
- Flow panels show dynamic counts where data is available
- Health issues in upstream stages produce amber/red dots on downstream arrows
- Tapping a propagated dot traces back to the source stage
- Sub-process expansion works in the Resolution stage
- All existing tests pass
- Build has zero warnings

## Handover Note

Only create `Documents/13-handoff.md` if work deviated from the plan. Record what was completed, what was not, any hitbox or animation issues with tappable arrows, and recommended next step.

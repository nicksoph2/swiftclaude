# Packet 22 — Instruction (CLAUDE.md) Tree and Full Preview

## Context

CLAUDE.md files stack and compose across scopes, and their load order determines their effective influence on Claude's behaviour. This packet adds a visual tree of how instruction files are composed, cycle detection for `@import` chains, token budget warnings, and full content preview for any instruction layer.

**Prerequisites: Packets 01, 10, 14 must be complete.**

## Prerequisites

- Packet 01 (pipeline wiring), Packet 10 (semantic validation for token warnings) complete

## Deliverables

### 1. `InstructionTreeView.swift`

Create `ClaudeConfigManager/Features/Instructions/InstructionTreeView.swift`.

The view renders the instruction composition as a visual tree within the Prompt Assembly stage.

**Tree nodes**: Each CLAUDE.md file is a node. Nodes are connected by lines representing:
- **Scope hierarchy**: the managed CLAUDE.md is the root, user comes next, then project, then project-local
- **`@import` relationships**: if a CLAUDE.md contains `@import path/to/file.md`, the imported file is a leaf connected to the importing node

**Node appearance**:
- File name (not full path — show just the filename)
- Scope badge (coloured by `ScopeColorScheme`)
- Discovery order index (integer badge: 1, 2, 3...)
- Token count (from `TokenEstimator`, shown as "~XXX tokens")
- "Last loaded" label on the final node in load order

**Influence encoding**: Nodes loaded later have stronger influence. Encode this visually:
- Node border thickness increases with load order (thinnest = first, thickest = last)
- Or: node background opacity increases with load order
- Choose whichever is more visually clear

**Tap a node**: Opens a preview popover (see below).

**`@import` parsing**: Scan the raw CLAUDE.md content for lines matching `@import <path>`. If an imported file is itself in the discovered file list, connect it in the tree. If the imported file was not discovered (missing file), show a dashed line to a ghost node with a "Not found" label.

### 2. Import cycle detection (J2)

When building the instruction tree, detect circular `@import` chains. A cycle exists if following `@import` links from any node eventually reaches that same node.

When a cycle is detected:
- Render the cycle path in red in the tree: each node in the cycle has a red border
- Show a red banner above the tree: "Import cycle detected"
- The cycle path: "file-a.md → file-b.md → file-c.md → file-a.md (cycle)"
- Explain: "file-c.md will not be loaded because of this cycle. Instructions from this file are missing from Claude's context."

Wire this into the semantic validator (Packet 10): add `.instructionImportCycle(cyclePath: [String])` error case and emit it from `SemanticValidator`.

### 3. Token budget warning (J3)

Add a token budget warning banner at the top of the Prompt Assembly stage:

- Compute total instruction tokens: sum of token counts across all resolved CLAUDE.md layers
- Threshold: 50,000 tokens (25% of a 200K context window)
- If exceeded: amber banner "Your instruction files are large — [total] tokens estimated across [N] files. This may consume a significant portion of Claude's context window."
- Show a bar chart below the banner: each CLAUDE.md file as a segment, coloured by scope. Width proportional to token count.
- "Tips" expandable section: "Use @import selectively to avoid loading large files in every session." / "Break large instruction files into smaller, more targeted ones."

If under threshold: no banner. Don't show warnings unnecessarily.

### 4. Full instruction content preview (J4)

Tapping a node in the instruction tree opens a preview popover:

- Header: file name, scope badge, token count, line count
- Full content in a monospace scroll view (not truncated)
- "Copy to clipboard" button (`UIPasteboard.general.string = content`)
- "Edit this file" button — enabled only if the file is at a writable scope. Opens the CLAUDE.md editor (this will be built in Packet 23; for now, show a "Coming soon" placeholder or open the file in the default text editor via `NSWorkspace.shared.open(fileURL)`)

### 5. Tests

Create `ClaudeConfigManagerTests/Features/InstructionTreeTests.swift`:

- **`testLoadOrderIndexIsSequential`** — three CLAUDE.md files → indices 1, 2, 3
- **`testCycleDetected`** — construct a graph where file-a imports file-b imports file-a → cycle error is emitted
- **`testNoCycleForLinearChain`** — a → b → c (no cycle) → no error
- **`testTokenBudgetWarningAboveThreshold`** — instruction total > 50,000 tokens → warning banner shown in view state
- **`testNoBannerBelowThreshold`** — instruction total < 50,000 tokens → no warning

## Build and Test

```bash
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager \
  -destination 'platform=macOS' -quiet 2>&1 | tail -30
```

**Done criteria:**
- Instruction tree renders in the Prompt Assembly stage with scope badges and load order indices
- Import relationships shown as connecting lines
- Missing imported files shown as ghost nodes
- Cycle detection triggers a red banner and highlights the cycle
- Token budget warning appears when threshold is exceeded
- Full content preview accessible from any node
- All existing tests pass, build has zero warnings

## Handover Note

Only create `Documents/22-handoff.md` if work deviated from the plan. Record what was completed, what was not, any difficulties with cycle detection or `@import` path resolution, and recommended next step.

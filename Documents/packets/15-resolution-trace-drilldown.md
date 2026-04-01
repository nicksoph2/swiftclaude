# Packet 15 — Resolution Trace Drill-Down

## Context

This is the **single most impactful user-facing feature not yet implemented**. When a user sees a resolved setting value, they should be able to tap it once and see exactly where it came from: which file, which scope, which value beat which, and what merge rule was applied. This panel makes the invisible visible.

**Prerequisites: Packets 01, 03, 09 must be complete.**

## Prerequisites

- Packet 01 (pipeline wiring), Packet 03 (key registry), Packet 09 (managed resolver) complete
- Packet 14 recommended (scope colours applied consistently — the trace panel relies on them)

## Deliverables

### 1. Read the resolver models

Read `ClaudeConfigManager/Infrastructure/Resolver/ResolverModels.swift` in full, focusing on:
- `ResolvedSettingsEntry` — the winning value plus provenance chain
- `ResolutionSource` — what a "participant scope" looks like
- `ScopeParticipant` / `ParticipationKind` — winning / overridden / merged / absent

Understand what data is already available in the resolved projection for each setting.

### 2. `ResolutionTracePanelView.swift`

Create `ClaudeConfigManager/Features/Tree/ResolutionTracePanelView.swift`.

This view takes a `ResolvedSettingsEntry` and renders:

**Header row**
- Key path in monospace bold (e.g. `permissions.deny`)
- Merge method badge (human-readable label from Packet 14, with icon)
- Close button

**Winning value section**
- Label: "Effective value"
- The winning value rendered appropriately for its type:
  - String → monospace text
  - Bool → toggle indicator (read-only)
  - Array → bulleted list, each item on its own line with a scope-coloured dot showing which scope contributed it (for array-merge keys)
  - Object → expandable key-value pairs
- Scope badge for the winning scope (`ScopeColorScheme.scopeBadge`)

**Provenance timeline** — a vertical list of every scope that had an opinion, in precedence order (Managed at top, CLI at bottom). For each scope row:
- Scope badge (coloured pill with scope name)
- Value declared by that scope (monospace, secondary size)
- Participation kind:
  - **Winning** — bold text, checkmark icon
  - **Overridden** — strikethrough text, `xmark` icon, dimmed
  - **Merged** — regular text, `plus` icon (for array contributions)
  - **Absent** — "—" placeholder, `.absent` grey

For **array-merge keys** specifically: below the provenance timeline, add a "Merged contributions" section showing a flat list of all array entries with a scope-coloured dot indicating which scope contributed each entry.

**"Go to source" button** — on the winning scope row, a button that navigates to the source file in the Discovery tree for that scope. Use the cross-stage navigation pattern from the existing tree view.

**File path** — below the winning scope row, show the file path of the source file in secondary monospace text.

### 3. Present `ResolutionTracePanelView` from resolved setting rows

Make every resolved setting row in the app tappable to open the trace panel:
- In the Resolution stage view
- In the User scope view (if it shows resolved settings)
- In the Project scope view (same)
- In the Session scope view (same)

Use `.sheet` presentation on windows narrower than 600pt and `.popover` on wider windows. Anchor popovers to the tapped row.

When a row is tapped, set a `@State var traceTarget: ResolvedSettingsEntry?`. Present the panel when non-nil.

### 4. Tests

Create `ClaudeConfigManagerTests/Features/ResolutionTracePanelTests.swift`:

- **`testPanelShowsWinningValue`** — construct a `ResolvedSettingsEntry` with a known winner → winning value appears in view state
- **`testOverriddenScopesHaveStrikethrough`** — provenance chain with one overridden scope → participation kind is `.overridden`
- **`testArrayMergeShowsAllContributors`** — an array-merge entry with two scopes → both scopes appear with `.merged` participation kind
- **`testAbsentScopesAreShown`** — a scope that did not define the key → appears as `.absent`

## Build and Test

```bash
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager \
  -destination 'platform=macOS' -quiet 2>&1 | tail -30
```

**Done criteria:**
- Tapping any resolved setting row opens the trace panel
- The panel shows the effective value, all contributing scopes, participation kinds, and merge method
- Array-merge keys show individual contributions with scope dots
- "Go to source" navigates to the correct Discovery tree node
- Panel adapts between sheet and popover based on window width
- All existing tests pass
- Build has zero warnings

## Handover Note

Only create `Documents/15-handoff.md` if work deviated from the plan. Record what was completed, what was not, any resolver model gaps that prevented full provenance display, and recommended next step.

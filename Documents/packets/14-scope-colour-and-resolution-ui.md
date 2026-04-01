# Packet 14 — Scope Colour Consistency and Resolution UI

## Context

`ScopeColorScheme` already exists as the single source of truth for scope colours, but many views in the app likely still use hardcoded colours or inconsistent styling. This packet does a full audit and applies consistent scope colours everywhere, then adds the two most impactful resolution UI improvements: human-readable merge labels and conflict highlighting.

**Prerequisite: Packets 01 and 03 must be complete. Benefits from 09 being complete for managed scope colour.**

## Prerequisites

- Packet 01 complete (pipeline wiring)
- Packet 03 complete (key registry)

## Deliverables

### Part A — Scope Colour Audit

#### 1. Audit all views

Search the project for any hardcoded `Color(...)`, `.red`, `.blue`, `.green`, `.teal`, `.orange`, `.purple` usages that are being used to represent scope identity rather than semantic UI meaning. Look in:
- All files under `Features/`
- `Core/ScopeColorScheme.swift` (to understand the official palette)
- Any `*ScopeView.swift`, `*Badge.swift`, or similar files

#### 2. Replace with `ScopeColorScheme`

For every instance found, replace it with `ScopeColorScheme.color(for: scope)` or `ScopeColorScheme.scopeBadge(for: scope)`. Do not change:
- Semantic colours (success/error/warning — these are not scope colours)
- SF Symbol rendering colours
- Text colours that are not scope-specific

#### 3. Verify in the app

After the change, open the app and visually confirm:
- Managed scope = red/amber
- User scope = blue
- Project scope = green
- Project-local scope = teal
- Session scope = orange
- CLI scope = purple

These colours must appear consistently in: resolution waterfall tiers, Discovery tree scope indicators, any scope badge pills.

---

### Part B — Human-Readable Merge Labels (C2)

#### 4. Find all merge method display sites

Search the codebase for where merge method identifiers like `selectHighestPrecedence`, `appendUnique`, `deepMergeObject` (or equivalent enum case names) are rendered to the user. There may be a `mergeMethodLabel` property or similar.

#### 5. Replace with user-facing labels

Change displayed labels to:
- `selectHighestPrecedence` / `.override` → **"Overrides — highest scope wins"**
- `appendUnique` / `.appendUnique` → **"Merges — all scopes combined"**
- `deepMergeObject` / `.deepMerge` → **"Deep merges — per-key precedence"**

Add a small icon next to each label:
- Override: `chevron.up` (single chevron — one winner)
- Merge: `arrow.triangle.merge` (converging arrows)
- Deep merge: `square.3.layers.3d` (stacked layers)

On hover / long-press, show a tooltip with the developer identifier (e.g. "selectHighestPrecedence"). Use `.help("selectHighestPrecedence")` in SwiftUI for the tooltip.

---

### Part C — Conflict Highlighting (C3)

#### 6. Add conflict badge to setting rows

In any settings list view that shows resolved settings (the Resolution stage view, the Session scope view, the User/Project scope views), check if a resolved setting has more than one scope contributing a value with different outcomes (i.e., it was "contested").

Add a small badge to the row:
- A circle with an exclamation mark (`exclamationmark.circle.fill`) in amber
- Accessibility label: "Resolved conflict — multiple scopes had different values for this key"

Use the existing `ResolvedSettingsEntry` provenance chain to determine if a conflict exists: more than one scope has a value AND at least one is `.overridden`.

#### 7. "Conflicts only" filter

In the Resolution stage view, add a filter button in the toolbar: "Show conflicts only" (SF Symbol `line.3.horizontal.decrease.circle`). When active, the list shows only settings with the conflict badge. When inactive, shows all settings.

Store the filter state in `@SceneStorage("showConflictsOnly")`.

#### 8. Tests

- **`testMergeLabelForEachMergeMethod`** — assert the user-facing label string is correct for each of the three merge methods
- **`testConflictBadgeAppearsForContestedKey`** — a `ResolvedSettingsEntry` with two scopes and one overridden → conflict badge is present in rendered state

## Build and Test

```bash
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager \
  -destination 'platform=macOS' -quiet 2>&1 | tail -30
```

**Done criteria:**
- No hardcoded scope colours remain in any view (verified by grep for `.blue`, `.red` etc. in `Features/`)
- Merge labels show user-facing text throughout the Resolution stage
- Merge icons appear next to labels
- Conflict badges appear on contested resolved settings rows
- "Conflicts only" filter works
- All existing tests pass
- Build has zero warnings

## Handover Note

Only create `Documents/14-handoff.md` if work deviated from the plan. Record what was completed, what was not, any scope colour inconsistencies that could not be easily remedied, and recommended next step.

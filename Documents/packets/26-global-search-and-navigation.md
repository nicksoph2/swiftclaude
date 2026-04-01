# Packet 26 — Global Search, Scope Stack Sidebar, and Keyboard Navigation

## Context

As the app grows richer, navigation needs to scale. This packet adds three navigation improvements: a global settings search activated by ⌘F, a restructured sidebar that visually communicates the scope precedence hierarchy, and full keyboard navigation.

**Prerequisites: Packets 01, 11, 12, 16 must be complete.**

## Prerequisites

- Packet 01, 11, 12, 16 complete (pipeline, diagram, dashboard)

## Deliverables

### 1. Global Settings Search (H2)

**`GlobalSearchView.swift`** — a search overlay that appears over the current view when ⌘F is pressed.

**Activation**: Register `KeyboardShortcut("f", modifiers: .command)` in the main view. Alternatively, add a toolbar search button. Opening the search focuses the search field.

**Search field**: Searches across:
- All resolved settings key names and their values (from `SessionProjection.settings.entries`)
- All file paths from the discovery scan
- All MCP server names
- All hook event type names
- CLAUDE.md file paths and first-line content

**Results list**: Updated as user types (debounced 150ms). Each result row:
- Type badge: "Setting", "File", "MCP", "Hook"
- Key/name in monospace
- Value or file path in secondary text
- Stage badge: which pipeline stage this belongs to

**Tap to navigate**: Tapping a result:
- Settings: zooms the diagram to the Resolution stage and highlights that key (opens the trace panel if available)
- File: zooms to Discovery stage and selects that file
- MCP server: zooms to MCP Servers stage and scrolls to that server
- Hook: zooms to Hooks Lifecycle stage and scrolls to that event

**Empty state**: "No results for '[query]'" — suggest searching for "model", "permissions.deny", or "bash".

**Suggested searches** when field is empty: chips for "model", "permissions.deny", "mcp", "hooks", "sandbox"

**Dismiss**: Escape key or clicking outside.

### 2. Scope Stack Sidebar (H3)

Restructure `SidebarView.swift`. Replace the current flat list of destinations with a visual scope stack:

**Structure:**

```
Dashboard                     (top item, not part of stack)
─────────────────────────────
Managed          [🔴 2 files] [0 issues]
User             [🔵 1 file]  [1 warning]
Project          [🟢 3 files] [0 issues]
Project-Local    [🟦 1 file]  [0 issues]
Session          [🟠 0 files] [inactive]
CLI              [🟣 —]       [inactive]
─────────────────────────────
Resolved Config               (output of stack)
─────────────────────────────
Pipeline View
Permissions
Issues                        [badge: X errors + warnings]
```

**Scope rows**: Each shows scope colour dot, scope name, file count badge, and issue badge. Inactive scopes (no files) are dimmer.

**Precedence indicator**: A vertical bar or arrow connecting the scope rows from top to bottom, labelled "Higher scopes take precedence" on hover.

**"Resolved Config"** links to the Resolution stage's resolved settings view (the most important single view in the app for Practitioners).

Update `AppRouter` selections to match the new structure.

### 3. Keyboard Navigation (H4)

**Pipeline diagram navigation:**
- Arrow keys move focus between diagram nodes (wrap around at edges)
- Return/Space on a focused node: zoom in to that stage
- Escape: zoom back out to the overview

**Stage content navigation:**
- Tab / Shift-Tab moves focus between interactive elements within a stage detail view
- Return on a setting row: open the trace panel (if available)
- Return on a file node: open the file detail popover

**Global shortcuts:**
- ⌘1: Dashboard
- ⌘2: Resolved Config (Resolution stage)
- ⌘3: Permissions
- ⌘4: Issues
- ⌘5: Pipeline View
- ⌘R: Refresh (re-run pipeline)
- ⌘E: Enter/exit Edit Mode (when in a settings view)
- ⌘F: Open global search
- Escape: Back / dismiss popover / exit Edit Mode

Register all shortcuts in the main scene's `commands { ... }` block. Use `@FocusState` and `focusable()` for in-view navigation.

**VoiceOver**: Every interactive custom element must have a meaningful `accessibilityLabel`. At minimum:
- Diagram nodes: "[Stage name] stage, [health status], tap to expand"
- Scope rows in sidebar: "[Scope name] scope, [N] files, [N] issues"
- Setting rows: "[Key name], [value], [scope name]"

### 4. Tests

- **`testSearchReturnsSettingForKeyName`** — inject a projection with a known key → searching that key name returns a result
- **`testSearchReturnsFileForPath`** — inject a scan result with a known file path → searching the filename returns a result
- **`testSidebarShowsFileCountBadges`** — mock scan result with 2 user-scope files → user scope row shows badge "2"
- **`testKeyboardShortcutRefresh`** — ⌘R triggers `pipeline.run()`

## Build and Test

```bash
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager \
  -destination 'platform=macOS' -quiet 2>&1 | tail -30
```

**Done criteria:**
- ⌘F opens global search overlay; results appear as user types
- Tapping a result navigates to the correct stage
- Sidebar shows scope stack with colour dots, file count badges, and issue badges
- Keyboard shortcuts work for all registered actions
- Arrow key navigation works in the pipeline diagram
- VoiceOver labels are set on all custom interactive elements
- All existing tests pass, build has zero warnings

## Handover Note

Only create `Documents/26-handoff.md` if work deviated from the plan. Record what was completed, what was not, any keyboard shortcut conflicts, and recommended next step.

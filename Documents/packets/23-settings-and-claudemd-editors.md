# Packet 23 — Settings File Editors and CLAUDE.md Editor

## Context

The editing flow built in Packets 18–19 handles intention-based editing through the resolved view. This packet adds **direct file editors** for users who want to edit specific scope files: a settings editor for user scope, a settings editor for project scope (with clear team-vs-personal distinction), and a CLAUDE.md editor with live token count.

**Prerequisites: Packets 17, 18, 19 must be complete.**

## Prerequisites

- Packet 17 (atomic write), Packet 18 (edit mode), Packet 19 (pre-save preview) complete

## Deliverables

### 1. `UserSettingsEditorView.swift`

Create `ClaudeConfigManager/Features/User/UserSettingsEditorView.swift`.

A structured settings editor for `~/.claude/settings.json` presented as a sheet from the User scope view.

**Layout**: A scrollable list of settings entries, grouped by the accessor categories from Packet 04 (Model, Permissions, Hooks, MCP Policy, Sandbox, UI, Worktree, Attribution).

**Each editable row**:
- Key name (monospace)
- Current value (type-appropriate display)
- Edit affordance: pencil icon at trailing edge

Tapping a row opens the same editor popover from Packet 18, but with the save scope locked to `.user` (no scope picker — the user is explicitly editing the user-scope file). This opens directly to the value field, skipping the scope recommendation step.

**"Add new setting" button**: Opens a picker of all registered settings keys (from the registry, filtered to keys valid at user scope) that are not already defined in this file. Selecting a key opens the editor for that key with a nil initial value.

**Footer**: Shows the file path, last modified timestamp, and file size.

### 2. `ProjectSettingsEditorView.swift`

Create `ClaudeConfigManager/Features/Project/ProjectSettingsEditorView.swift`.

Identical structure to `UserSettingsEditorView` but shows two sections:

**"Team settings" section** — edits `.claude/settings.json`:
- Header: "[filename] — shared with team" with a person.2 icon
- Same grouped list as above

**"Personal settings" section** — edits `.claude/settings.local.json`:
- Header: "[filename] — personal override, not shared" with a person icon
- Visually distinct: lighter background, dashed border or different section colour
- Callout: "Changes here override team settings but are not committed to version control."

Both sections use `AtomicFileWriter` targeting the respective file. The scope for team settings is `.project`; for personal settings, `.projectLocal`.

### 3. `ClaudeMdEditorView.swift`

Create `ClaudeConfigManager/Features/Instructions/ClaudeMdEditorView.swift`.

A Markdown text editor for CLAUDE.md files presented as a sheet.

**Toolbar**:
- File name and scope badge
- Live token count: "~XXX tokens" updated as the user types (debounced 300ms, computed by `TokenEstimator`)
- Token budget indicator: green if under threshold, amber if over 25% of context window (>50K tokens)
- "Prompt Assembly position: #N" — load order index from the resolved instruction tree

**Editor area**:
- A `TextEditor` with monospace font and word wrap
- No Markdown rendering — plain text editing. This is intentional: CLAUDE.md files are instruction text, not formatted documents.

**Save button** (toolbar trailing):
- Enabled when there are unsaved changes
- Calls `AtomicFileWriter` to write the content atomically
- Shows a progress indicator while saving
- On success: shows a brief "Saved" confirmation in the toolbar

**Warning panel** (shown if token count exceeds threshold):
- "This file is large. Consider splitting it or using @import to load sections conditionally."

**`@import` reference** — at the bottom, a collapsible "Imported files" list: paths mentioned in `@import` directives with a status icon (found / not found).

**Discard prompt**: if the user tries to dismiss with unsaved changes, show a confirmation: "Discard changes?" / "Save first?"

### 4. Wire editors into scope views

- User scope view: add "Edit settings.json" button → presents `UserSettingsEditorView`
- Project scope view: add "Edit project settings" button → presents `ProjectSettingsEditorView`
- Instruction tree node tap (Packet 22): "Edit this file" button → presents `ClaudeMdEditorView` for the tapped file

### 5. Tests

- **`testUserEditorGroupsKeysByCategory`** — a `SettingsDocument` with keys from different categories → rows appear in correct groups
- **`testProjectEditorShowsTwoSections`** — both team and personal settings files present → two sections rendered
- **`testClaudeMdTokenCountUpdatesOnChange`** — insert text into the editor → token count updates within 300ms debounce window
- **`testClaudeMdSaveIsAtomic`** — verify save calls `AtomicFileWriter` (use dependency injection)

## Build and Test

```bash
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager \
  -destination 'platform=macOS' -quiet 2>&1 | tail -30
```

**Done criteria:**
- User settings editor accessible from User scope view
- Project settings editor shows team and personal sections clearly
- CLAUDE.md editor shows live token count and position in load order
- All three editors save via `AtomicFileWriter` with the atomic guarantees
- Unsaved changes are protected by a discard prompt
- All existing tests pass, build has zero warnings

## Handover Note

Only create `Documents/23-handoff.md` if work deviated from the plan. Record what was completed, what was not, and recommended next step.

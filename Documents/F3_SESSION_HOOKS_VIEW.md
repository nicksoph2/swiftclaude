# Packet F3 - Session Hooks View

## Goal
Implement the read-only Session hooks screen.

## Why this packet exists
Hooks can be difficult to reason about once settings are merged. The Session hooks screen should present effective hooks, grouping, restrictions, and issues clearly.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_F_SESSION_UI.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D7_SESSION_PROJECTION.md`

## Dependencies
- `D7_SESSION_PROJECTION`

## Deliverables
- read-only Session hooks screen
- UI models or adapters for grouped hook display
- diagnostics presentation for hook restrictions and issues
- UI tests or view-state tests where practical

## Required behavior
- show effective hooks grouped by event and matcher where relevant
- show restrictions such as managed-only limitations
- show issues and notes related to invalid or ignored hooks
- remain read-only

## Suggested Swift types
- `SessionHooksView`
- `HookGroupModel`
- `HookRowModel`
- `HookRestrictionBadgeModel`

## Acceptance criteria
- effective hooks are inspectable without reading merged JSON manually
- grouping and restrictions are understandable
- partial or invalid hook states remain visible
- UI does not embed merge logic locally

## Out of scope
- editing controls
- non-hook Session screens
- save-preview behavior

## Done when
- users can inspect the effective hook surface and its issues from the Session scope

## Suggested next packet
- `F4_SESSION_MCP_VIEW`

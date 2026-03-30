# Packet F3 - Session Hooks View

## Goal
Implement the read-only Session hooks screen driven by resolved settings/hooks projection data.

## Why this packet exists
Hook behavior can become opaque after merges and restrictions are applied. The Session hooks screen should make effective hooks and policy limitations visible.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_F_SESSION_UI.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D7_SESSION_PROJECTION.md`

## Dependencies
- `D7_SESSION_PROJECTION`

## Deliverables
- `SessionHooksView` (read-only)
- grouped hooks presentation model (event/matcher/action structure)
- restrictions and policy badge presentation model
- issue presentation for invalid/ignored hook entries
- view-state tests or UI tests for representative hook states

## Required behavior
### Display requirements
- show effective hooks grouped by event and matcher context
- show hook action summaries with source provenance
- show restriction states (for example managed-only constraints)
- show warnings/errors for ignored or invalid hook definitions

### State handling
Support and test:
- hooks absent state
- hooks present with multiple groups
- restrictions active state
- invalid hook entries with diagnostics
- partial state with missing source details

### Interaction boundaries
- read-only only
- no local merge or policy recomputation
- optional expansion/collapse for large hook groups is acceptable

## Suggested Swift types
- `SessionHooksView`
- `SessionHooksViewModel`
- `HookGroupModel`
- `HookRowModel`
- `HookRestrictionBadgeModel`
- `HookIssueModel`

## Test fixture guidance
Create view-state tests for:
- deterministic grouping/sorting
- restriction badges rendering
- invalid-hook diagnostics visibility
- empty and partial projection states

## Acceptance criteria
- users can inspect effective hook surface and restrictions without reading merged JSON manually
- diagnostic states are visible and attributable
- screen is read-only and projection-driven

## Out of scope
- hook editing controls
- resolver merge logic
- non-hook Session screens

## Done when
- Session hooks screen reliably presents effective hook behavior, provenance, and diagnostics

## Suggested next packet
- `F4_SESSION_MCP_VIEW`

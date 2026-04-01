# Packet F1 - Session Settings View

## Goal
Implement the read-only Session settings screen backed only by `SessionProjection` data.

## Why this packet exists
Users need a reliable way to inspect effective settings, source provenance, and merge behavior without opening multiple raw files. This screen is the primary trust surface for settings resolution.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_F_SESSION_UI.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D7_SESSION_PROJECTION.md`
- validation issue model outputs from Section E when available

## Dependencies
- `D7_SESSION_PROJECTION`
- Section E validation outputs when available

## Deliverables
- `SessionSettingsView` (read-only)
- view-model/adapter mapping projection settings snapshot into sections/rows
- provenance presentation (winning source + participants + merge method)
- issue presentation at row/section level
- view-state tests or UI tests for key states

## Required behavior
### Display requirements
- show effective settings grouped into understandable sections
- show winning source for each relevant value
- show participating/overridden sources where useful
- show merge method for merged values
- show row/section diagnostics and notes

### State handling
Support and test:
- normal populated state
- partial/incomplete projection state
- empty/no-data state
- error/issue-heavy state

### Interaction boundaries
- read-only only (no edit/save controls)
- optional affordances like expand/collapse, copy path/value, and source-inspection links are acceptable if they do not perform resolver logic
- view must not recompute precedence/merge locally

## Suggested Swift types
- `SessionSettingsView`
- `SessionSettingsViewModel`
- `SessionSettingsSectionModel`
- `ResolvedSettingRowModel`
- `SourceChipModel`
- `IssueBadgeModel`

## Test fixture guidance
Create view-state tests for:
- settings with single-source values
- settings with multi-source merge traces
- unresolved/missing-value rows
- rows with warnings/errors
- deterministic sorting of sections/rows

## Acceptance criteria
- screen is read-only and projection-driven
- users can inspect effective values and provenance without leaving Session scope
- partial/missing projection data is handled gracefully
- UI remains stable and deterministic for identical projection input

## Out of scope
- editing and save-preview workflows
- resolver implementation
- non-settings Session views

## Done when
- Session settings screen reliably presents effective values, provenance, and diagnostics from `SessionProjection`

## Suggested next packet
- `F2_SESSION_INSTRUCTIONS_VIEW`

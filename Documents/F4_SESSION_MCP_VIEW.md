# Packet F4 - Session MCP View

## Goal
Implement the read-only Session MCP screen that presents effective MCP servers, overrides, and diagnostics.

## Why this packet exists
MCP configuration can span multiple files and scopes. Users need one screen that explains effective visibility and conflicts without requiring raw-file diffing.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_F_SESSION_UI.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D5_MCP_RESOLUTION.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D7_SESSION_PROJECTION.md`

## Dependencies
- `D5_MCP_RESOLUTION`
- `D7_SESSION_PROJECTION`

## Deliverables
- `SessionMCPView` (read-only)
- effective-server list model and overridden-definition model
- diagnostics model for conflicts/env notes/invalid definitions
- view-state tests or UI tests for representative MCP states

## Required behavior
### Display requirements
- show effective server definitions with source labels
- show overridden definitions and why they were overridden
- show precedence/provenance traces in inspectable form
- show diagnostics (duplicate ids, transport conflicts, env-related notes)

### State handling
Support and test:
- no MCP servers state
- single-source servers state
- multi-source override state
- conflict-heavy diagnostic state
- partial/incomplete snapshot state

### Interaction boundaries
- screen is read-only
- no local precedence/merge computation in UI layer
- optional expandable detail rows are acceptable for provenance and diagnostics

## Suggested Swift types
- `SessionMCPView`
- `SessionMCPViewModel`
- `McpServerRowModel`
- `OverriddenServerModel`
- `McpDiagnosticModel`
- `SourceChipModel`

## Test fixture guidance
Create view-state tests for:
- deterministic server ordering
- override details visibility
- conflict and env-note badge visibility
- empty and partial states

## Acceptance criteria
- users can inspect effective MCP visibility and source provenance without editing files
- overridden/conflicting definitions are visible and attributable
- screen remains projection-driven and read-only

## Out of scope
- MCP transport parsing logic
- MCP resolver logic
- non-MCP Session screens

## Done when
- Session MCP screen provides a trustworthy, inspectable MCP state view from `SessionProjection`

## Suggested next packet
- `F5_SESSION_AGENTS_SKILLS_VIEW`

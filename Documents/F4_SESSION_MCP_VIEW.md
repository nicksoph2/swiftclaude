# Packet F4 - Session MCP View

## Goal
Implement the read-only Session MCP screen.

## Why this packet exists
MCP visibility, precedence, and duplicates are difficult to understand from raw files. The Session MCP screen should show effective servers and overridden definitions clearly.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_F_SESSION_UI.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D5_MCP_RESOLUTION.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D7_SESSION_PROJECTION.md`

## Dependencies
- `D5_MCP_RESOLUTION`
- `D7_SESSION_PROJECTION`

## Deliverables
- read-only Session MCP screen
- UI models or adapters for effective and overridden servers
- diagnostics presentation for duplicate and env-related issues
- UI tests or view-state tests where practical

## Required behavior
- show effective MCP servers
- show overridden definitions and their sources
- show source precedence and provenance clearly
- show diagnostics such as unresolved env behavior or conflicting definitions
- remain read-only

## Suggested Swift types
- `SessionMCPView`
- `McpServerRowModel`
- `OverriddenServerModel`
- `McpDiagnosticBadgeModel`

## Acceptance criteria
- users can inspect effective server visibility and provenance without editing files
- overridden and conflicting definitions remain visible
- diagnostics are surfaced clearly
- UI does not perform MCP resolution locally

## Out of scope
- editing controls
- transport parsing
- non-MCP Session screens

## Done when
- users can inspect the effective MCP surface from the Session scope

## Suggested next packet
- `F5_SESSION_AGENTS_SKILLS_VIEW`

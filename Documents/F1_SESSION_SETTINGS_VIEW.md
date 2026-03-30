# Packet F1 - Session Settings View

## Goal
Implement the read-only Session settings screen.

## Why this packet exists
Users need a trustworthy place to inspect effective settings, their winning sources, merge methods, and related issues without switching between raw files.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_F_SESSION_UI.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D7_SESSION_PROJECTION.md`

## Dependencies
- `D7_SESSION_PROJECTION`

## Deliverables
- read-only Session settings screen
- UI models or view-model adapters as needed
- issue and provenance presentation for settings values
- UI tests or view-state tests where practical

## Required behavior
- show effective values
- show winning source and participating sources
- show merge method where relevant
- show issues and notes near the affected values or sections
- remain usable when some values are unresolved or partial

## Suggested Swift types
- `SessionSettingsView`
- `SessionSettingsSectionModel`
- `ResolvedSettingRowModel`
- `SourceChipModel`

## Acceptance criteria
- the screen is read-only
- settings provenance is inspectable without opening editors
- partial or missing data states are handled cleanly
- UI does not recalculate resolver logic locally

## Out of scope
- editing controls
- save previews
- non-settings Session screens

## Done when
- users can inspect effective settings and understand where they came from in the Session scope

## Suggested next packet
- `F2_SESSION_INSTRUCTIONS_VIEW`

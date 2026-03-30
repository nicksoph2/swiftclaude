# Packet F2 - Session Instructions View

## Goal
Implement the read-only Session instructions screen that presents resolved load order, import participation, and memory-related instruction state.

## Why this packet exists
Instruction behavior is difficult to infer from raw markdown and imports. The Session screen must make instruction order and diagnostics understandable at a glance.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_F_SESSION_UI.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D4_INSTRUCTION_RESOLUTION.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D7_SESSION_PROJECTION.md`

## Dependencies
- `D4_INSTRUCTION_RESOLUTION`
- `D7_SESSION_PROJECTION`

## Deliverables
- `SessionInstructionsView` (read-only)
- view-model/adapter for load order, imports, and memory projections
- diagnostics display for cycles, missing imports, and depth-limit issues
- view-state tests or UI tests for key scenarios

## Required behavior
### Display requirements
- show resolved instruction load order in deterministic sequence
- show import relationships per instruction entry
- distinguish startup-loaded memory from on-demand memory topics
- show diagnostics and partial-resolution notes inline and/or in summary

### State handling
Support and test:
- no-import simple state
- nested import state
- cycle/missing-import diagnostic state
- startup-memory and on-demand-memory combined state
- partial-resolution state where some entries fail

### Interaction boundaries
- remain read-only
- allow inspectable provenance and source paths
- do not perform traversal/resolution logic in view code

## Suggested Swift types
- `SessionInstructionsView`
- `SessionInstructionsViewModel`
- `InstructionEntryRowModel`
- `ImportRelationModel`
- `AutoMemorySectionModel`
- `InstructionIssueSummaryModel`

## Test fixture guidance
Create view-state tests for:
- deterministic row ordering
- cycle diagnostics visibility
- unresolved import visibility
- startup vs on-demand memory separation
- empty/partial states

## Acceptance criteria
- instructions screen makes load order/import participation understandable without file-by-file inspection
- memory participation is represented distinctly and clearly
- diagnostic-heavy states remain usable and read-only
- UI depends only on projection models

## Out of scope
- markdown parsing
- instruction resolver logic
- non-instruction Session screens

## Done when
- users can inspect effective instruction behavior, import relationships, and memory boundaries from Session scope

## Suggested next packet
- `F3_SESSION_HOOKS_VIEW`

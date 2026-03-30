# Packet F2 - Session Instructions View

## Goal
Implement the read-only Session instructions screen.

## Why this packet exists
Instruction behavior is difficult to reason about from files alone. The Session instructions screen should make load order, imports, startup-loaded content, and diagnostics visible in one place.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_F_SESSION_UI.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D4_INSTRUCTION_RESOLUTION.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D7_SESSION_PROJECTION.md`

## Dependencies
- `D4_INSTRUCTION_RESOLUTION`
- `D7_SESSION_PROJECTION`

## Deliverables
- read-only Session instructions screen
- UI models or adapters for load order and imports
- diagnostics presentation for cycles, broken imports, and memory boundaries
- UI tests or view-state tests where practical

## Required behavior
- show resolved instruction load order
- show import relationships clearly
- distinguish startup-loaded instructions from available on-demand memory
- show diagnostics and partial-resolution notes
- remain read-only

## Suggested Swift types
- `SessionInstructionsView`
- `InstructionEntryRowModel`
- `ImportGraphNodeModel`
- `AutoMemorySectionModel`

## Acceptance criteria
- the screen makes instruction participation inspectable without editing files
- import and memory behavior are represented distinctly
- cycles and broken imports are surfaced clearly
- UI does not perform resolver work locally

## Out of scope
- editing controls
- markdown parsing
- non-instruction Session screens

## Done when
- users can inspect effective instructions, imports, and memory-related participation from the Session scope

## Suggested next packet
- `F3_SESSION_HOOKS_VIEW`

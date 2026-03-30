# Packet F5 - Session Agents and Skills View

## Goal
Implement the read-only Session agents and skills screen.

## Why this packet exists
Users need one place to understand which agents and skills are effectively visible, which definitions were overridden, and which ones have validation problems.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_F_SESSION_UI.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D6_AGENT_SKILL_RESOLUTION.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D7_SESSION_PROJECTION.md`

## Dependencies
- `D6_AGENT_SKILL_RESOLUTION`
- `D7_SESSION_PROJECTION`

## Deliverables
- read-only Session agents and skills screen
- UI models or adapters for visibility and override presentation
- diagnostics presentation for duplicates and invalid definitions
- UI tests or view-state tests where practical

## Required behavior
- show effective agents and skills by scope
- show overridden or shadowed definitions
- show duplicates, invalid frontmatter, and related diagnostics
- remain read-only

## Suggested Swift types
- `SessionAgentsSkillsView`
- `AgentVisibilityRowModel`
- `SkillVisibilityRowModel`
- `OverrideSummaryModel`

## Acceptance criteria
- users can inspect effective visibility and provenance for agents and skills
- overridden and invalid definitions remain visible
- UI does not recalculate precedence locally
- the screen stays read-only

## Out of scope
- editing controls
- parser behavior
- non-agent and non-skill Session screens

## Done when
- users can inspect the effective agent and skill surface from the Session scope with provenance and diagnostics

## Suggested next packet
- `I1_FIXTURE_LAYOUT`

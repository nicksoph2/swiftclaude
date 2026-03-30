# Packet F5 - Session Agents and Skills View

## Goal
Implement the read-only Session agents-and-skills screen showing effective visibility, overrides, and diagnostics.

## Why this packet exists
Agent/skill availability is scope-sensitive and can include duplicates or invalid definitions. Users need one consolidated view to understand what is effective.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_F_SESSION_UI.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D6_AGENT_SKILL_RESOLUTION.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D7_SESSION_PROJECTION.md`

## Dependencies
- `D6_AGENT_SKILL_RESOLUTION`
- `D7_SESSION_PROJECTION`

## Deliverables
- `SessionAgentsSkillsView` (read-only)
- visibility/override presentation models for agents and skills
- diagnostic presentation for duplicates, malformed definitions, and unavailable entries
- view-state tests or UI tests for representative scenarios

## Required behavior
### Display requirements
- show effective agents and skills with scope/source badges
- show overridden/shadowed entries and their winning replacements
- show invalid or unavailable entries distinctly from overridden entries
- show diagnostics with source attribution

### State handling
Support and test:
- clean effective-only state
- override-heavy state
- duplicate/conflict state
- invalid-definition state
- partial/missing data state

### Interaction boundaries
- remain read-only
- no local precedence logic
- optional segmented or tabbed presentation for agents vs skills is acceptable

## Suggested Swift types
- `SessionAgentsSkillsView`
- `SessionAgentsSkillsViewModel`
- `AgentVisibilityRowModel`
- `SkillVisibilityRowModel`
- `OverrideSummaryModel`
- `AgentSkillIssueModel`

## Test fixture guidance
Create view-state tests for:
- deterministic sorting
- overridden entry visibility
- invalid/duplicate diagnostics visibility
- empty/partial states

## Acceptance criteria
- effective visibility for agents and skills is clear and inspectable
- overridden and invalid entries remain visible with provenance
- UI stays projection-driven and read-only

## Out of scope
- editing controls
- parser or resolver logic
- non-agent/skill Session screens

## Done when
- users can inspect the effective agent and skill surface with provenance and diagnostics from Session scope

## Suggested next packet
- `I1_FIXTURE_LAYOUT`

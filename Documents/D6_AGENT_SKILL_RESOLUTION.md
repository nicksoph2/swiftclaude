# Packet D6 - Agent and Skill Resolution

## Goal
Implement effective visibility and precedence rules for agents and skills across scopes.

## Why this packet exists
The app must show which agents and skills are effectively available, how project scope overrides user scope, and which duplicates or malformed definitions need attention.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_D_RESOLVER.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D1_RESOLVER_MODELS.md`
- parsed agent documents from `C5_AGENT_PARSER`
- parsed skill documents from `C6_SKILL_PARSER`

## Dependencies
- `C5_AGENT_PARSER`
- `C6_SKILL_PARSER`
- `D1_RESOLVER_MODELS`

## Deliverables
- `AgentResolver`
- `SkillResolver`
- precedence rules for user and project scope
- duplicate-name and unsupported-shape diagnostics
- unit tests for visibility and override scenarios

## Required behavior
### Agent rules
- prefer project agents over user agents when names collide
- preserve overridden definitions for provenance
- surface malformed or unsupported agent definitions as issues rather than silently dropping them

### Skill rules
- represent skills by scope and visibility
- preserve invalid frontmatter and missing-reference diagnostics for later Session presentation
- distinguish hidden, invalid, and overridden skill states

## Suggested Swift types
- `ResolvedAgentSnapshot`
- `ResolvedSkillSnapshot`
- `ResolvedAgentEntry`
- `ResolvedSkillEntry`
- `ResolutionIssue`

## Acceptance criteria
- effective visibility is deterministic for the same inputs
- duplicate names and overrides are inspectable in provenance
- invalid but discovered definitions are represented explicitly
- parser logic remains separate from resolution logic

## Out of scope
- editing behavior
- UI layout
- save preview behavior

## Done when
- Session projection packets can consume one resolved agent snapshot and one resolved skill snapshot with visibility, provenance, and diagnostics

## Suggested next packet
- `D7_SESSION_PROJECTION`

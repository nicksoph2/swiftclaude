# Packet D6 - Agent and Skill Resolution

## Goal
Implement deterministic visibility and precedence resolution for agents and skills across user and project scopes.

## Why this packet exists
The Session view needs one coherent picture of which agents and skills are effectively available, which are overridden, and which are invalid or partially usable.

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
- effective visibility and precedence rules by scope
- override/conflict diagnostics for duplicates and invalid definitions
- resolved snapshots for agents and skills with provenance
- deterministic unit tests for visibility scenarios

## Required behavior
### Agent resolution rules
- resolve by agent identity (name/key) with explicit normalization policy
- prefer project-scoped definitions over user-scoped definitions when identities collide
- preserve overridden agent definitions for provenance display
- carry parse/shape issues into resolution issues without silently dropping entries

### Skill resolution rules
- resolve skill visibility from discovered skill directories by scope
- preserve invalid/missing-structure skills as discovered-but-problematic entries
- distinguish states such as effective, overridden, invalid, and unavailable
- preserve supporting-reference diagnostics from parser output for downstream validation display

### Determinism and provenance
- stable ordering for effective and overridden entries
- explicit source traces for each resolved entry
- explicit issue attribution for collisions and malformed definitions

## Suggested Swift types
- `AgentResolver`
- `SkillResolver`
- `ResolvedAgentSnapshot`
- `ResolvedSkillSnapshot`
- `ResolvedAgentEntry`
- `ResolvedSkillEntry`
- `VisibilityState`
- `ResolutionIssue`

## Test fixture guidance
Create tests for:
- user-only agents and skills
- project overrides user entries
- duplicate identities in same scope
- malformed agent frontmatter carried into resolved output
- missing or malformed skill documents carried into resolved output
- deterministic ordering for effective and overridden entries

## Acceptance criteria
- effective agent/skill visibility is deterministic and inspectable
- overrides and invalid entries remain visible with provenance and issues
- parser concerns remain separate from resolution concerns
- output is consumable by Session projection without re-deriving precedence

## Out of scope
- editing workflows
- UI layout and interaction
- runtime execution validation of tools/scripts

## Done when
- `D7_SESSION_PROJECTION` can consume resolved agent and skill snapshots with effective/overridden/invalid states and diagnostics

## Suggested next packet
- `D7_SESSION_PROJECTION`

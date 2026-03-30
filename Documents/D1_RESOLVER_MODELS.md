# Packet D1 - Resolver Models

## Goal
Define the shared domain models used by all resolver families and by the Session projection.

## Why this packet exists
Before implementing precedence logic, the project needs stable types for resolved values, traces, merge methods, issues, and source provenance.

## Inputs
- `Docs/PROJECT_INDEX.md`
- `Docs/Sections/SECTION_D_RESOLVER.md`
- parser output model shapes from Section C
- discovery output model shapes from Section B

## Dependencies
- Discovery and parser packet outputs can be partial or mocked, but this packet should anticipate their interfaces cleanly

## Deliverables
- shared resolver domain types
- source provenance model
- merge method enum or equivalent
- trace model for participating sources
- Session projection skeleton type

## Suggested Swift types
- `ResolutionSource`
- `ResolutionSourceKind`
- `ResolutionTrace`
- `MergeMethod`
- `ResolutionIssue`
- `ResolutionNote`
- `ResolvedValue<T>`
- `ResolvedCollection<Item>` if useful
- `ResolvedSettingsSnapshot`
- `ResolvedInstructionSnapshot`
- `ResolvedMcpSnapshot`
- `ResolvedAgentSnapshot`
- `ResolvedSkillSnapshot`
- `SessionProjection`

## Required modeling behaviors
### Resolved value shape
Every resolved field should be able to surface:
- effective value
- winning source
- all participating sources
- merge method
- validation issues
- notes

### Source provenance
A source should be able to represent:
- scope
- path or virtual source identity
- source kind such as managed, user, project, local, CLI, imported, auto-memory
- availability status if relevant

### Issues
Issues should support at least:
- severity
- stable code
- user-facing message
- optional source link or range

## Acceptance criteria
- Shared resolver types are expressive enough for settings, instructions, MCP, agents, and skills
- The model does not hard-code rules that belong in later precedence packets
- The model is suitable for both internal resolver logic and Session UI inspection
- The Session projection type can aggregate all resolved snapshots without forcing persistence

## Out of scope
- actual precedence algorithms
- merge implementation
- UI rendering details
- save preview details

## Done when
- Later resolver packets can build logic on top of these types without redefining basic concepts
- Unit tests can instantiate representative resolved values and traces cleanly

## Suggested next packet
- `D2_SETTINGS_PRECEDENCE`

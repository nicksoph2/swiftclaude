# Packet D1 - Resolver Models

## Goal
Define shared resolver domain models for effective values, provenance traces, issues, and family snapshots used by all resolver packets and the Session projection.

## Why this packet exists
Resolver packets `D2` through `D7` need consistent contracts for "what was resolved," "why," and "from where." Without shared models, each resolver family would drift and Session UI contracts would become unstable.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_D_RESOLVER.md`
- parser output shapes from Section C
- discovery output shapes from Section B

## Dependencies
- none hard-required; parser/discovery types may be partially stubbed while defining resolver models

## Deliverables
- shared resolver domain types
- source provenance model and source-kind taxonomy
- merge method taxonomy
- trace model for winning and participating sources
- issue/note model for resolution-time diagnostics
- family snapshot types for settings, instructions, MCP, agents, and skills
- top-level `SessionProjection` skeleton contract

## Required behavior
### Shared resolved-value contract
Every resolved field/entry contract should be able to represent:
- effective value (or unresolved state)
- winning source
- participating sources in deterministic order
- merge/selection method
- attached resolution issues and notes

### Source provenance contract
A `ResolutionSource` should support:
- scope (`managed`, `user`, `project`, `projectLocal`, `session`, etc. as needed)
- source kind (`managed`, `cli`, `file`, `imported`, `autoMemory`, virtual synthetic source)
- concrete source identifier (path or virtual id)
- availability state (present, missing, invalid, inaccessible)

### Resolution issue contract
Resolution issues should support:
- stable issue code
- severity
- message
- optional source link/range
- optional related sources for conflict reporting

### Determinism rules
- model types should make stable ordering explicit (for traces/collections)
- output equality should be practical for deterministic tests
- contracts should not assume UI-specific formatting

## Suggested Swift types
- `ResolvedValue<Value>`
- `ResolutionSource`
- `ResolutionSourceKind`
- `ResolutionScope`
- `ResolutionAvailability`
- `ResolutionTrace`
- `MergeMethod`
- `ResolutionIssue`
- `ResolutionIssueCode`
- `ResolvedSettingsSnapshot`
- `ResolvedInstructionSnapshot`
- `ResolvedMcpSnapshot`
- `ResolvedAgentSnapshot`
- `ResolvedSkillSnapshot`
- `SessionProjection`

## Suggested model shape (non-binding)
```swift
struct ResolvedValue<Value> {
    let effectiveValue: Value?
    let winningSource: ResolutionSource?
    let trace: ResolutionTrace
    let mergeMethod: MergeMethod
    let issues: [ResolutionIssue]
}

struct ResolutionTrace {
    let participants: [ResolutionSource]
    let overridden: [ResolutionSource]
    let notes: [String]
}
```

## Acceptance criteria
- resolver models are expressive enough for all Section D families
- contracts preserve provenance and issue attribution without UI coupling
- model shapes avoid embedding precedence logic that belongs in later packets
- Session projection can aggregate family snapshots without persistence assumptions

## Out of scope
- precedence algorithms
- merge algorithms
- validation policy
- UI layout and presentation

## Done when
- packets `D2` to `D7` can build implementation logic directly against these shared types
- model unit tests can construct representative snapshots and trace scenarios cleanly

## Suggested next packet
- `D2_SETTINGS_PRECEDENCE`

# Packet D7 - Session Projection

## Goal
Assemble one read-only `SessionProjection` from all resolved families and validation outputs, preserving provenance and partial-state diagnostics.

## Why this packet exists
Session UI should consume one stable computed contract rather than calling each resolver directly. This packet unifies outputs while preserving traceability and without introducing persistence.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_D_RESOLVER.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D1_RESOLVER_MODELS.md`
- resolved outputs from `D2` through `D6`
- validation outputs from Section E when available

## Dependencies
- `D1_RESOLVER_MODELS`
- `D2_SETTINGS_PRECEDENCE`
- `D3_SETTINGS_MERGE_RULES`
- `D4_INSTRUCTION_RESOLUTION`
- `D5_MCP_RESOLUTION`
- `D6_AGENT_SKILL_RESOLUTION`

## Deliverables
- `SessionProjectionBuilder`
- aggregate `SessionProjection` model assembly
- top-level issue summaries and completeness indicators
- deterministic ordering policy for projection collections
- unit tests for projection integrity under mixed valid/invalid states

## Required behavior
### Projection composition
Session projection should include:
- resolved settings snapshot
- resolved instructions snapshot
- resolved hooks projection derived from resolved settings where applicable
- resolved MCP snapshot
- resolved agent snapshot
- resolved skill snapshot
- aggregated issue summary (parser/resolver/validation as available)
- completeness/confidence metadata for partial states

### Partial-state behavior
- support missing families without crashing
- represent unavailable/incomplete families explicitly
- preserve family-level and projection-level issues

### Provenance and stability
- keep per-family provenance traces accessible for UI consumption
- enforce deterministic ordering for stable tests and UI behavior
- avoid UI-specific formatting logic inside projection builder

### Read-only boundary
- projection is computed, never persisted as shadow truth
- projection builder must not write files

## Suggested Swift types
- `SessionProjectionBuilder`
- `SessionProjection`
- `SessionIssueSummary`
- `SessionCompleteness`
- `SessionProvenanceSummary`
- `ProjectionFamilyState`

## Test fixture guidance
Create tests for:
- full projection with all families present
- projection with one or more missing families
- projection with mixed valid/invalid family snapshots
- deterministic ordering of rows/collections in projection payload
- issue aggregation consistency across parser/resolver/validation sources

## Acceptance criteria
- one aggregate projection can be built from representative resolved inputs
- projection is stable, inspectable, and read-only
- partial/incomplete states are explicit and non-fatal
- Session UI packets can consume projection without invoking resolver logic

## Out of scope
- Session UI layout and interaction behavior
- editor/save-preview workflows
- persistence/database behavior

## Done when
- `SessionProjectionBuilder` can return a deterministic projection contract ready for Section F views

## Suggested next packet
- `E1_VALIDATION_MODELS`

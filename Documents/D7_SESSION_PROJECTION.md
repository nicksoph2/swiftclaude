# Packet D7 - Session Projection

## Goal
Assemble the read-only Session projection from all resolved families into one inspectable model.

## Why this packet exists
The Session UI needs one coherent computed snapshot that aggregates effective settings, instructions, hooks, MCP servers, agents, skills, provenance, and issues without creating a shadow database.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_D_RESOLVER.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D1_RESOLVER_MODELS.md`
- resolved outputs from `D2` through `D6`

## Dependencies
- `D1_RESOLVER_MODELS`
- `D2_SETTINGS_PRECEDENCE`
- `D3_SETTINGS_MERGE_RULES`
- `D4_INSTRUCTION_RESOLUTION`
- `D5_MCP_RESOLUTION`
- `D6_AGENT_SKILL_RESOLUTION`

## Deliverables
- `SessionProjectionBuilder`
- aggregate `SessionProjection`
- consistent top-level issue and provenance summaries
- unit tests for projection integrity and representative mixed scenarios

## Required behavior
### Projection contents
- resolved settings snapshot
- resolved instruction snapshot
- resolved hooks view data derived from resolved settings when relevant
- resolved MCP snapshot
- resolved agent snapshot
- resolved skill snapshot
- combined issue summary
- confidence or completeness notes for partial states

### Projection rules
- keep Session computed and read-only
- preserve enough source and trace information for later UI inspection
- represent partial resolution states without forcing persistence

## Suggested Swift types
- `SessionProjectionBuilder`
- `SessionProjection`
- `SessionIssueSummary`
- `SessionCompleteness`
- `SessionProvenanceSummary`

## Acceptance criteria
- one aggregate projection can be built from representative resolved inputs
- the projection exposes the resolved families needed by the planned Session UI
- partial or incomplete inputs are represented cleanly instead of crashing or silently disappearing
- no persistence layer is introduced

## Out of scope
- Session UI layout
- editing behavior
- save preview behavior

## Done when
- the Session UI packets can consume a single read-only projection contract without knowing the details of each resolver family

## Suggested next packet
- `SECTION_E_VALIDATION`

# Packet D4 - Instruction Resolution

## Goal
Implement deterministic resolution for instruction markdown, imports, and auto-memory participation in the Session view.

## Why this packet exists
Instruction behavior is one of the most important parts of the product. The app must explain load order, imported content, auto-memory boundaries, and broken references without persisting a shadow instruction graph.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_D_RESOLVER.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D1_RESOLVER_MODELS.md`
- parsed markdown from `C4_CLAUDE_MD_PARSER`
- discovery models for memory directories and imported files

## Dependencies
- `B3_DISCOVERY_MODELS`
- `C4_CLAUDE_MD_PARSER`
- `D1_RESOLVER_MODELS`

## Deliverables
- `InstructionResolver`
- load-order model
- import-graph traversal and diagnostics
- startup-loaded versus on-demand memory modeling
- unit tests for load-order, cycles, and broken imports

## Required behavior
### Load order
- model managed instructions when present
- include user `CLAUDE.md`
- include project `CLAUDE.md`
- include project `.claude/CLAUDE.md`
- represent imported files in traversal order
- separate startup-loaded auto-memory from available on-demand memory topics

### Resolution rules
- support recursive import resolution only to the documented maximum depth
- detect cycles and repeated imports
- surface broken or inaccessible imports as issues
- keep raw parsed bodies separate from resolved instruction entries

## Suggested Swift types
- `InstructionResolver`
- `ResolvedInstructionEntry`
- `InstructionLoadOrder`
- `InstructionImportGraph`
- `AutoMemoryProjection`
- `ResolutionIssue`

## Acceptance criteria
- the same parsed instruction inputs produce the same resolved load order
- cycles, missing imports, and depth-limit issues are traceable
- startup-loaded and on-demand memory are represented distinctly
- parser and resolution responsibilities stay separate

## Out of scope
- markdown parsing
- editor behavior
- UI-specific layout choices

## Done when
- Session projection packets can consume one resolved instruction snapshot with provenance, import participation, and diagnostics

## Suggested next packet
- `D5_MCP_RESOLUTION`

# Packet D4 - Instruction Resolution

## Goal
Define and implement deterministic instruction resolution across root instruction files, imported instruction files, and auto-memory attachments, while preserving strict boundaries between parser concerns and resolver concerns.

## Why this packet exists
Instruction behavior comes from a layered graph, not one file. The resolver must answer:
- which instruction documents are loaded and in what order
- how imports were traversed and attributed
- which failures occurred (missing imports, cycles, depth overflow)
- which memory entries are startup-loaded versus on-demand only

This packet keeps that behavior explicit and testable so Session output is explainable and deterministic.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/AI_DRAFT_OTHERS_HANDOFF.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_D_RESOLVER.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/C4_CLAUDE_MD_PARSER.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D1_RESOLVER_MODELS.md`
- parsed `CLAUDE.md` documents and import tokens from `C4_CLAUDE_MD_PARSER`
- discovery outputs for:
  - managed instruction file (if present)
  - user instruction file (`~/.claude/CLAUDE.md`)
  - project instruction file (`<project>/CLAUDE.md`)
  - project-local instruction file (`<project>/.claude/CLAUDE.md`)
  - auto-memory directory/index/topic files under user project memory area

## Dependencies
- `B3_DISCOVERY_MODELS`
- `C4_CLAUDE_MD_PARSER`
- `D1_RESOLVER_MODELS`

## Deliverables
- `InstructionResolver`
- deterministic instruction root load plan
- recursive import resolver with explicit max-depth policy
- resolved instruction graph model with provenance
- diagnostics for unresolved imports, inaccessible files, invalid import targets, cycles, and depth overflow
- separate startup-memory and on-demand-memory projection model
- deterministic resolver tests and fixtures

## Required behavior
### Separation of concerns
- consume parser output from `C4`; do not re-parse markdown
- keep parse diagnostics from `C4` attached and visible
- keep resolver diagnostics distinct from parser diagnostics
- do not move parsing logic into resolver types

### Distinction: user-authored instructions vs auto memory
- user-authored instructions are:
  - managed `CLAUDE.md` (if provided)
  - user `~/.claude/CLAUDE.md`
  - project `<project>/CLAUDE.md`
  - project-local `<project>/.claude/CLAUDE.md`
  - transitively imported instruction files reachable from those roots
- auto memory is a separate family of content:
  - startup-loaded memory slice
  - on-demand memory topics
- auto memory must not be represented as imported `CLAUDE.md` nodes
- output model must preserve this boundary clearly for Session consumers

### Root instruction load order
Apply canonical root ordering:
1. managed instruction source (when present)
2. user `~/.claude/CLAUDE.md`
3. project `<project>/CLAUDE.md`
4. project-local `<project>/.claude/CLAUDE.md`

Rules:
- if a root is missing, record availability and continue
- root ordering remains stable regardless of missing roots
- no dynamic reordering by content or timestamps

### Recursive import resolution
For each loaded root, traverse imports depth-first in token order.

Resolution policy:
- evaluate import tokens in the order returned by `C4`
- resolve token path against the parent document path using deterministic rules
- normalize canonical file identity for cycle/repeat detection
- preserve every traversal step as an attributed edge:
  - parent source id
  - token location/token text
  - target source id or unresolved target descriptor
- allow repeated references; do not silently drop them

### Allowed recursion depth
- define a single `maxInstructionImportDepth` policy in resolver config/constants
- depth is measured as edge distance from a root document
- when a target would exceed max depth:
  - do not expand that branch
  - emit a deterministic depth-limit issue with parent/target context
  - continue resolving other branches

### Cycle handling
- detect cycles by canonical document identity in current traversal stack
- emit cycle issue including cycle path participants in deterministic order
- represent cycle edge in graph diagnostics/provenance
- stop only the cyclical branch; continue with remaining graph work

### Broken import diagnostics
Emit resolver issues for:
- import target not found
- import target inaccessible/unreadable
- import target resolved to unsupported file type (if encountered)
- import target known invalid from parser stage (attach relation and continue)

All issues must include source attribution and stable issue codes.

### Partial-success behavior
- one failed branch must not invalidate unrelated successful branches
- resolved snapshot should include all successful documents plus attributable issues
- unresolved branches remain visible through diagnostics and unresolved edges

### Startup memory vs on-demand memory projection
Represent memory separately from user-authored instruction graph.

Startup memory projection:
- deterministic ordered list of memory entries loaded at startup
- per-entry source metadata and availability
- parser/validation/resolution issues attached per entry as applicable

On-demand memory projection:
- deterministic ordered list/index of available topics not loaded by default
- source metadata and availability
- issues for inaccessible/corrupt topic entries without blocking others

### Snapshot output contract
`ResolvedInstructionSnapshot` should include:
- ordered root load plan with availability
- resolved user-authored instruction entries
- import graph (edges + node metadata)
- traversal trace/provenance for each entry
- parser diagnostics carried through
- resolver diagnostics produced in this packet
- startup memory projection
- on-demand memory projection

## Suggested Swift types
- `InstructionResolver`
- `InstructionRootPlan`
- `ResolvedInstructionSnapshot`
- `ResolvedInstructionEntry`
- `InstructionImportGraph`
- `InstructionImportEdge`
- `InstructionTraversalTrace`
- `InstructionDepthPolicy`
- `AutoMemoryStartupProjection`
- `AutoMemoryOnDemandProjection`
- `ResolutionIssue`

## Suggested implementation notes (non-binding)
- implement in two explicit phases:
  1. root + import graph resolution for user-authored instructions
  2. memory projection build (startup/on-demand)
- keep deterministic ordering helpers centralized and testable
- keep issue-code constants centralized for snapshot-stable tests
- prefer immutable snapshot structures once resolution is complete

## Test fixture guidance
Add resolver tests for at least:
- single user root with no imports
- full root set present and ordered correctly
- missing roots with stable ordering of remaining roots
- nested imports in deterministic traversal order
- repeated import token references preserved as distinct edges
- cycle of length 2 and longer cycle chains
- depth-limit overflow at boundary and beyond-boundary
- missing import target and inaccessible import target
- mix of successful and failed branches with partial success retained
- startup memory present with deterministic ordering
- on-demand memory topics present with deterministic ordering
- startup memory missing/corrupt while instruction graph still resolves
- strict boundary test: auto memory is not represented as user import nodes

## Acceptance criteria
- instruction resolution is deterministic for identical inputs
- root ordering and recursive traversal are explicit and test-covered
- cycle, depth, and broken-import diagnostics are attributable and stable
- user-authored instruction graph and auto-memory projections are clearly separate
- parser concerns remain in `C4`; resolver consumes parser outputs only
- `D7_SESSION_PROJECTION` can consume this snapshot without re-resolving imports

## Out of scope
- markdown tokenization/parsing logic (`C4`)
- schema/semantic policy outside resolver provenance modeling (Section E)
- Session UI rendering details (Section F)
- editing/write-back behavior

## Done when
- `InstructionResolver` produces a complete `ResolvedInstructionSnapshot` containing:
  - deterministic root and import load output
  - attributed diagnostics for cycles/depth/broken imports
  - separate startup/on-demand memory projections
- fixture-backed tests verify deterministic behavior and boundary separation

## Suggested next packet
- `D5_MCP_RESOLUTION`

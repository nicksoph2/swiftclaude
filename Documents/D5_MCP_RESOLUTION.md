# Packet D5 - MCP Resolution

## Goal
Define and implement deterministic cross-scope MCP server resolution across local, project, user, and managed sources, including precedence, duplicate handling, and environment-expansion behavior without transport parsing or UI coupling.

## Why this packet exists
MCP definitions can appear in multiple source families with overlapping server identifiers. Session needs one explainable effective view that answers:
- which server definition wins for each server id
- which definitions were overridden or ignored
- which entries are unresolved/invalid and why
- which fields still require runtime environment expansion

This packet keeps resolver policy explicit and testable, while preserving boundaries:
- parser packets (`C2`, `C3`) own JSON shape and transport parsing
- this packet owns cross-source selection and conflict attribution
- Section F owns display, not resolution logic

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/AI_DRAFT_OTHERS_HANDOFF.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_D_RESOLVER.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D1_RESOLVER_MODELS.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/C2_CLAUDE_JSON_PARSER.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/C3_MCP_JSON_PARSER.md`
- parsed `~/.claude.json` MCP data from `C2_CLAUDE_JSON_PARSER`
- parsed project `.mcp.json` data from `C3_MCP_JSON_PARSER`
- managed MCP input model if available

## Dependencies
- `C2_CLAUDE_JSON_PARSER`
- `C3_MCP_JSON_PARSER`
- `D1_RESOLVER_MODELS`

## Deliverables
- `MCPResolver`
- deterministic source-candidate builder for MCP entries by server id
- precedence selection stage for MCP entries
- effective + overridden MCP server snapshot contracts with provenance traces
- duplicate/conflict diagnostic rules for same-id and same-source collisions
- environment-reference note model (without interpolation/expansion execution)
- fixture-backed tests for precedence, duplicate handling, and env-note behavior

## Required behavior
### Canonical source precedence
Resolve by server identifier using this fixed order:
1. local-scoped MCP entries in `~/.claude.json`
2. project `.mcp.json`
3. user-scoped MCP entries in `~/.claude.json`
4. managed MCP entries

Rules:
- precedence is static and not data-dependent
- missing tiers do not reorder remaining tiers
- invalid higher tiers can emit issues and allow fallback to usable lower tiers

### Source normalization and candidate model
- normalize all parsed MCP entries into a common `McpSourceCandidate` shape:
  - `serverID`
  - `ResolutionSource` (scope, kind, file/virtual id)
  - precedence tier
  - availability (`present`, `missing`, `invalid`, `inaccessible`)
  - parsed MCP payload reference
  - parser issues carried forward
- candidate ordering must be deterministic:
  - by precedence tier
  - then by stable source tie-break key
  - then by stable discovery order if still tied

### Resolution behavior
- group candidates by canonical server identifier
- for each server id, select the highest-precedence usable candidate as winner
- include non-winning candidates in trace as overridden/ignored contributors
- preserve source attribution for every candidate regardless of win state
- include unavailable or invalid candidates as diagnostics participants, not silent drops
- produce unresolved entries when no usable candidate exists for a known id

### Duplicate server handling
Handle duplicates explicitly at two levels.

Cross-scope duplicate (same `serverID` across different tiers):
- expected and resolved by precedence
- emit trace note indicating override path when multiple usable candidates exist
- emit issue when higher-precedence candidate is invalid and fallback is used

Same-scope duplicate (same `serverID` appears more than once in one logical source):
- emit deterministic duplicate-definition issue
- apply deterministic in-source tie-break policy:
  - if parser already canonicalized to one value, preserve parser-selected value and reference parser issue
  - otherwise prefer last-defined entry in parse-order and emit explicit resolver note
- keep all duplicate contributors in diagnostics metadata when available

### Candidate usability and fallback policy
- usable candidate:
  - structurally valid enough for resolver consumption
  - not marked unavailable/inaccessible
- unusable candidate:
  - invalid structure, inaccessible source, or parser-failed entry
- selection policy:
  - prefer highest-precedence usable candidate
  - if highest precedence is unusable, emit issue and continue fallback search
  - if all candidates are unusable, create unresolved result with full issues/trace

### Environment behavior
- do not expand, interpolate, or execute environment lookups in resolver
- inspect candidate payload fields for environment references (for example in `command`, `args`, `env`, `url`, `headers` raw values as provided by parser output)
- attach deterministic notes/issues that classify environment references:
  - static literal (no expansion marker detected)
  - contains env-reference pattern
  - unresolved env-reference pattern (cannot be validated here)
- preserve raw values unchanged in resolved snapshot
- keep process launch and network validation out of scope

### Transport-boundary rule
- do not parse or reinterpret MCP transport forms in this packet
- consume transport-kind/result only from parser outputs (`C2`, `C3`)
- if transport ambiguity exists, propagate parser diagnostics and apply precedence on candidate usability only

### Snapshot contract requirements
`ResolvedMcpSnapshot` should include:
- deterministic ordered list of resolved server entries
- per-server effective candidate and winning source
- per-server trace:
  - participants (ordered)
  - overridden contributors
  - fallback steps taken due to unusable higher tiers
- per-server issues and notes
- unresolved server entries with attributable reasons
- top-level snapshot issues for document-level resolver faults

### Determinism requirements
- stable server-id ordering in final output
- stable participant ordering inside each server trace
- stable issue codes and tie-break behavior for duplicates
- snapshot equality suitable for fixture-based assertions

## Suggested Swift types
- `MCPResolver`
- `McpSourceTier`
- `McpSourceCandidate`
- `McpCandidateUsability`
- `ResolvedMcpSnapshot`
- `ResolvedMcpServer`
- `McpResolutionTrace`
- `McpOverrideEvent`
- `McpDuplicateDefinition`
- `McpEnvironmentNote`
- `ResolutionIssue`

## Test fixture guidance
Create resolver tests for:
- one server id defined in one tier only
- same server id across all four tiers with expected winner
- mixed ids where different tiers win per id
- missing higher tiers with stable ordering of remaining tiers
- invalid local candidate with valid project fallback
- invalid project candidate with valid user fallback
- all candidates invalid leading to unresolved server entry
- same-scope duplicate id behavior with deterministic tie-break + issue emission
- cross-scope duplicate id behavior with override trace
- transport-ambiguous candidate propagated from parser diagnostics without reparsing
- environment-reference detection notes on raw MCP fields
- deterministic output ordering for:
  - server ids
  - trace participants
  - issues/notes
- boundary case confirming no transport parsing logic is reintroduced in resolver

## Acceptance criteria
- precedence across local/project/user/managed MCP sources is deterministic and test-covered
- effective winners, overridden contributors, and fallback events are inspectable per server id
- duplicate definitions are surfaced with stable issue codes and deterministic tie-break behavior
- environment references are surfaced as notes/issues without mutating raw values
- parser-owned transport parsing remains outside resolver implementation
- `ResolvedMcpSnapshot` is directly consumable by `D7_SESSION_PROJECTION`

## Out of scope
- JSON decoding and MCP transport parsing (`C2`, `C3`)
- network reachability checks
- command execution checks
- environment interpolation/expansion execution
- Session UI rendering
- editor write behavior

## Done when
- `MCPResolver` produces deterministic per-id effective results across all source tiers
- duplicate and fallback behavior is fixture-tested and attributable
- environment-reference notes are included without runtime expansion
- `D7_SESSION_PROJECTION` can consume resolved MCP results without re-running precedence logic

## Suggested next packet
- `D6_AGENT_SKILL_RESOLUTION`

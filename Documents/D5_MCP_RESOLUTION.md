# Packet D5 - MCP Resolution

## Goal
Implement cross-scope resolution for MCP server definitions and related environment behavior.

## Why this packet exists
The app must explain which MCP servers are effectively visible, which source defined them, how duplicates are handled, and where unresolved environment behavior remains ambiguous.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_D_RESOLVER.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D1_RESOLVER_MODELS.md`
- parsed `~/.claude.json` data from `C2_CLAUDE_JSON_PARSER`
- parsed `.mcp.json` data from `C3_MCP_JSON_PARSER`

## Dependencies
- `C2_CLAUDE_JSON_PARSER`
- `C3_MCP_JSON_PARSER`
- `D1_RESOLVER_MODELS`

## Deliverables
- `MCPResolver`
- effective-server resolution across scopes
- duplicate-name handling policy
- environment-expansion notes and diagnostics
- tests for precedence and duplicate scenarios

## Required behavior
### Source families
- local-scoped MCP entries in `~/.claude.json`
- project `.mcp.json`
- user-scoped MCP entries in `~/.claude.json`
- managed MCP when available

### Resolver rules
- resolve effective server definitions by name
- preserve overridden and participating definitions in provenance traces
- classify duplicate-name conflicts and incompatible transport-shape conflicts
- represent unresolved environment-expansion questions as issues or notes rather than silently substituting values

## Suggested Swift types
- `MCPResolver`
- `ResolvedMcpServer`
- `McpResolutionTrace`
- `McpEnvironmentNote`
- `ResolutionIssue`

## Acceptance criteria
- effective MCP server visibility is deterministic for the same inputs
- overridden definitions remain inspectable in provenance
- unresolved env behavior and conflicting shapes are surfaced clearly
- transport parsing remains separate from resolver behavior

## Out of scope
- network connectivity checks
- editor behavior
- UI rendering

## Done when
- the Session projection can present effective MCP server state with provenance and diagnostics

## Suggested next packet
- `D6_AGENT_SKILL_RESOLUTION`

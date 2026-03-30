# Packet C3 - MCP JSON Parser

## Goal
Implement parsing for `.mcp.json` into typed server-definition models with parse-time diagnostics.

## Why this packet exists
The resolver needs a normalized representation of MCP servers before it can reason about precedence, duplicates, and environment behavior.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_C_PARSERS.md`
- discovery file references for `.mcp.json`

## Dependencies
- `B3_DISCOVERY_MODELS` should exist or be stubbed enough to supply file references

## Deliverables
- `McpParser`
- `ParsedMcpDocument`
- typed server-definition models
- syntax issue reporting
- fixture-backed unit tests

## Required behavior
### Supported structures
- top-level MCP server container
- server identifiers
- transport variants such as command-based and URL-based forms
- args arrays
- env maps
- headers maps
- optional enablement or metadata fields where documented

### Parser rules
- normalize parse output into one consistent server-definition shape
- keep environment expansion and precedence out of this packet
- preserve enough raw information for later diagnostics

## Suggested Swift types
- `ParsedMcpDocument`
- `ParsedMcpServer`
- `McpTransportKind`
- `ParsedCommandTransport`
- `ParsedUrlTransport`
- `SyntaxIssue`

## Test fixture guidance
Create fixtures for:
- valid command-based server
- valid URL-based server
- mixed valid server set
- invalid JSON
- malformed args and env shapes
- malformed headers shape

## Acceptance criteria
- valid `.mcp.json` files parse into typed server models
- invalid JSON and invalid shape errors are reported clearly
- transport parsing remains distinct from later resolution behavior
- parser output is suitable for cross-scope MCP resolution

## Out of scope
- precedence between user, local, project, and managed servers
- environment expansion
- network reachability checks
- UI rendering

## Done when
- later MCP resolver packets can operate on typed parsed server definitions instead of raw JSON

## Suggested next packet
- `C4_CLAUDE_MD_PARSER`

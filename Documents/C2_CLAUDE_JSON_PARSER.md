# Packet C2 - Claude JSON Parser

## Goal
Implement parsing for `~/.claude.json` into a typed domain model distinct from `settings.json`.

## Why this packet exists
`~/.claude.json` carries different responsibilities from `settings.json`, including user and local MCP state and related user-level metadata. Resolver and validation packets need a parser that keeps those concerns separate.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_C_PARSERS.md`
- discovery file references for `~/.claude.json`

## Dependencies
- `B3_DISCOVERY_MODELS` should exist or be stubbed enough to supply file references
- `C1_SETTINGS_JSON_PARSER` for shared parse infrastructure if useful

## Deliverables
- `ClaudeJsonParser`
- `ParsedClaudeJsonDocument`
- typed submodels for supported `~/.claude.json` structures
- syntax issue reporting
- fixture-backed unit tests

## Required behavior
### Parsing scope
- parse `~/.claude.json` as a separate file family
- model top-level preferences and MCP-related storage that belongs to this file
- support unknown-field preservation for forward compatibility where practical

### Important separation rules
- do not treat `settings.json` fields as first-class `~/.claude.json` fields
- do not implement precedence or merge behavior here
- keep environment expansion out of this parser unless required for parse-time shape validation only

## Suggested Swift types
- `ParsedClaudeJsonDocument`
- `ClaudeJsonDocumentValue`
- `ParsedClaudeJsonMcpState`
- `ParsedTrustState`
- `SyntaxIssue`
- `IssueSeverity`

## Test fixture guidance
Create fixtures for:
- valid baseline `~/.claude.json`
- valid user MCP entries
- valid local MCP entries
- invalid JSON
- malformed nested MCP structures
- unknown top-level fields preserved safely

## Acceptance criteria
- valid `~/.claude.json` files parse into a typed model without being conflated with `settings.json`
- invalid JSON produces clear syntax diagnostics
- supported nested structures are modeled explicitly
- parser output is suitable for later MCP and preference resolution packets

## Out of scope
- `settings.json`
- `.mcp.json`
- precedence or merge behavior
- canonical rendering back to disk

## Done when
- later resolver packets can consume parsed `~/.claude.json` data without re-parsing raw JSON

## Suggested next packet
- `C3_MCP_JSON_PARSER`

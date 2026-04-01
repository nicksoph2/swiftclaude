# Packet C2 - Claude JSON Parser

## Goal
Implement parsing for `~/.claude.json` into a typed domain model that is explicitly separate from the `settings.json` file family.

## Why this packet exists
`~/.claude.json` carries different responsibilities from `settings.json`, including global Claude Code preferences and user or local MCP state. Resolver and validation packets need a dedicated parser that does not blur boundaries between these two JSON families.

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
- source-location aware syntax issue reporting
- fixture-backed unit tests

## Required behavior
### Supported parsing scope
- parse only `~/.claude.json` in this packet
- model global preferences that belong to this file family
- model user or local MCP state blocks stored in this file family
- model trust-state or related user metadata when present
- preserve unknown fields where practical for forward compatibility

### Important separation rules
- do not treat `settings.json` keys as first-class `~/.claude.json` fields
- do not backfill missing `~/.claude.json` fields from any `settings.json` file
- do not implement precedence or merge behavior here
- do not run resolver-time interpretation in this parser
- keep environment expansion out of this parser except basic shape parsing where unavoidable

## Suggested Swift types
- `ParsedClaudeJsonDocument`
- `ClaudeJsonDocumentValue`
- `ClaudeJsonGlobalPreferences`
- `ParsedClaudeJsonMcpState`
- `ParsedClaudeJsonMcpServerRef`
- `ParsedTrustState`
- `SyntaxIssue`
- `IssueSeverity`

## Test fixture guidance
Create fixtures for:
- valid baseline `~/.claude.json`
- valid global preferences block
- valid user MCP entries inside `~/.claude.json`
- valid local MCP entries inside `~/.claude.json`
- valid trust-state examples
- invalid JSON
- malformed nested MCP structures
- malformed trust-state structures
- unknown top-level fields preserved safely
- files that resemble `settings.json` and are rejected or captured as unknown without becoming modeled fields

## Acceptance criteria
- valid `~/.claude.json` files parse into a typed model without being conflated with `settings.json` parsing
- invalid JSON produces clear syntax diagnostics
- supported global preference, MCP-state, and trust-state structures are modeled explicitly
- parser output includes enough raw provenance and location context for downstream diagnostics
- parser output is suitable for later MCP and preference resolution packets

## Out of scope
- `settings.json`
- `.mcp.json`
- precedence or merge behavior
- cross-file conflict resolution
- semantic policy enforcement
- canonical rendering back to disk

## Done when
- later resolver packets can consume parsed `~/.claude.json` values without re-parsing raw JSON
- test fixtures cover both valid structures and family-boundary confusion cases (`settings.json`-like keys in `~/.claude.json`)

## Suggested next packet
- `C3_MCP_JSON_PARSER`

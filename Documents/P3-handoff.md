# P3 Handoff

## Packet

Packet P3: MCP Transport Types and Per-Server Policy

## Files created or modified for this packet

- `ClaudeConfigManager/Infrastructure/Parsers/ClaudeJsonParser.swift`
- `ClaudeConfigManager/Infrastructure/Parsers/SettingsParser.swift`
- `ClaudeConfigManager/Infrastructure/Resolver/ResolverModels.swift`
- `ClaudeConfigManager/Infrastructure/Discovery/WorkspaceScanner.swift`
- `ClaudeConfigManagerTests/Parsers/ClaudeJsonParserTests.swift`
- `ClaudeConfigManagerTests/Parsers/McpJsonParserTests.swift`
- `ClaudeConfigManagerTests/Resolver/ResolverModelsTests.swift`
- `ClaudeConfigManagerTests/Fixtures/parsers/mcp_json/README.md`
- `ClaudeConfigManagerTests/Fixtures/parsers/mcp_json/valid_mcp_transports/input/.mcp.json`
- `ClaudeConfigManagerTests/Fixtures/parsers/mcp_json/valid_mcp_transports/expected/parser_issues.json`
- `ClaudeConfigManagerTests/Fixtures/parsers/mcp_json/invalid_mcp_transports/input/.mcp.json`
- `ClaudeConfigManagerTests/Fixtures/parsers/mcp_json/invalid_mcp_transports/expected/parser_issues.json`

## What changed

- Added explicit MCP transport modeling with:
  - `McpTransportType` (`stdio`, `http`, `sse`, `plugin`, `unknown`)
  - `McpServerSource` provenance (`.mcpJson(path:)`, `.claudeJson`, `.managed`, `.plugin(id:)`)
  - `McpServerConfig` for normalized per-server transport data
- Extended parsed MCP server refs to expose:
  - `transportType`
  - `cwd`
  - `pluginId`
  - `pluginName`
  - `serverSource`
  - `config.unknownFields`
- Updated shared MCP parsing in `ClaudeJsonParser` to:
  - detect `stdio` via `command`
  - detect `http` via `url`
  - detect deprecated `sse` via `url` + `transport: "sse"`
  - detect plugin-provided servers via `pluginId`
  - warn on empty transport definitions
  - warn on ambiguous `command` + `url` definitions while preferring `stdio`
  - emit info-level deprecation issues for SSE
- Kept existing raw-object/legacy field behavior intact so downstream resolver/UI code continues to work.
- Adjusted schema validation for parsed Claude JSON MCP entries to respect the new transport model instead of forcing the old exact `command xor url` rule.

## Test and fixture coverage added

- Added parser coverage for:
  - stdio with `cwd`
  - streamable HTTP with headers
  - SSE deprecation
  - plugin-provided MCP servers
  - empty server definitions
  - ambiguous transport definitions
  - provenance for `.claude.json`, `.mcp.json`, and `managed-mcp.json`
- Added `.mcp.json` fixtures:
  - `valid_mcp_transports`
  - `invalid_mcp_transports`

## Verification-driven cleanup fixes

These were discovered while running the required suite and were fixed to return the repo to green:

- `WorkspaceScanner.swift`
  - Fixed MDM plist array normalization so `NSNumber(value: 1)` is treated as a number rather than being misclassified as `Bool`.
- `ResolverModelsTests.swift`
  - Corrected a managed MCP precedence expectation to match the resolver’s existing documented MCP precedence (`local -> project -> user -> managed`).

## Assumptions

- In this codebase, MCP parsing remains centered in `ClaudeJsonParser`, and `.mcp.json` coverage continues to be exercised through that shared MCP parsing path rather than a separate dedicated parser type.
- `transport: "sse"` is the only currently required SSE indicator for this packet.
- Plugin-provided MCP entries should carry `.plugin(id:)` provenance when `pluginId` is present, even if the parse entry originated from a managed/effective source file.

## Differences from the prompt/doc paths

- The prompt referenced `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp`, but the live workspace was mounted at `/Users/nicholassophocleous/Documents/Dev/claude/devDiscoverApp`.
- I implemented and verified against the live mounted workspace path.

## Verification

- Ran:
  - `xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager -destination 'platform=macOS' -quiet`
- Result:
  - Passed

## Recommended next packet

- `H3` if continuing the hooks track
- or `M4` / `R1` depending on the current orchestration order after P3

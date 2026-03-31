# P2 Handoff

## Packet

Packet P2: MCP Server Control Keys

## Files created or modified

- `ClaudeConfigManager/Infrastructure/Parsers/SettingsParser.swift`
- `ClaudeConfigManager/Infrastructure/Parsers/SettingsKeyRegistry.swift`
- `ClaudeConfigManager/Infrastructure/Resolver/ResolverModels.swift`
- `ClaudeConfigManagerTests/Parsers/SettingsParserTests.swift`
- `ClaudeConfigManagerTests/Parsers/SettingsDocumentValueAccessorsTests.swift`
- `ClaudeConfigManagerTests/Fixtures/parsers/settings/README.md`
- `ClaudeConfigManagerTests/Fixtures/parsers/settings/current_hook_event_catalog/expected/parser_issues.json`
- `ClaudeConfigManagerTests/Fixtures/parsers/settings/valid_registry_modern/input/settings.json`
- `ClaudeConfigManagerTests/Fixtures/parsers/settings/valid_registry_modern/expected/summary.json`
- `ClaudeConfigManagerTests/Fixtures/parsers/settings/valid_mcp_controls/input/settings.json`
- `ClaudeConfigManagerTests/Fixtures/parsers/settings/valid_mcp_controls/expected/parser_issues.json`
- `ClaudeConfigManagerTests/Fixtures/parsers/settings/invalid_mcp_controls/input/settings.json`
- `ClaudeConfigManagerTests/Fixtures/parsers/settings/invalid_mcp_controls/expected/parser_issues.json`

## What changed

- Added typed MCP control support to `SettingsParser` for:
  - `allowManagedMcpServersOnly`
  - `enableAllProjectMcpServers`
  - `enabledMcpjsonServers`
  - `disabledMcpjsonServers`
  - `allowedMcpServers`
  - `deniedMcpServers`
- Added typed `McpRestrictionRule` parsing with discriminated-union enforcement for `serverName`, `serverCommand`, and `serverUrl`.
- Preserved unknown MCP rule fields for forward compatibility.
- Added scope-aware warning support for managed-only MCP settings when a non-managed scope is supplied to the parser.
- Updated registry metadata for MCP settings to the current documented schema.
- Added/updated parser fixtures and tests for valid/invalid MCP controls and accessor coverage.

## Key decisions and assumptions

- Added optional `scope: ResolutionScope?` parser entry points rather than changing existing call sites; existing parser usage remains source-compatible.
- Treated malformed top-level MCP array settings as error-severity issues per the packet test expectations.
- For malformed `serverCommand`, emitted:
  - a warning-level `typeMismatch` on `serverCommand`
  - an error-level `invalidMcpRestrictionRule` on the containing rule when no valid discriminator remains
- Used `isManagedOnly` plus parser-side scope diagnostics for MCP managed-only keys instead of introducing a separate validation phase in this packet.

## Issues encountered

- The user-provided repo path used a different username segment than the active workspace path. I resolved all work against:
  - `/Users/nicholassophocleous/Documents/Dev/claude/devDiscoverApp`
- The full test suite initially failed because `xcodebuild` could not write DerivedData inside the sandbox; reran with elevated permissions.
- The suite also surfaced a missing expected fixture directory for `current_hook_event_catalog`; I added the missing expected issue file so the existing test could pass.

## Verification

- Ran:
  - `xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager -destination 'platform=macOS' -quiet`
- Result:
  - Passed

## Open questions or follow-up risks

- The parser now carries typed MCP restriction rules, but resolver-side enforcement semantics for deny-over-allow behavior remain future work outside this packet.
- The worktree contains many unrelated pre-existing modifications; only the files listed above were part of this packet.

## Recommended next packet

- `P3` to continue the MCP/settings permissions track while the MCP control schema and diagnostics are fresh.

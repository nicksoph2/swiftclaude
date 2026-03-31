# G1 Handoff

## Files created or modified

- `ClaudeConfigManager/Infrastructure/Parsers/SettingsKeyRegistry.swift`
- `ClaudeConfigManager/Infrastructure/Parsers/SettingsParser.swift`
- `ClaudeConfigManagerTests/Parsers/SettingsParserTests.swift`
- `ClaudeConfigManagerTests/Fixtures/parsers/settings/README.md`
- `ClaudeConfigManagerTests/Fixtures/parsers/settings/valid_registry_modern/input/settings.json`
- `ClaudeConfigManagerTests/Fixtures/parsers/settings/valid_registry_modern/expected/summary.json`
- `ClaudeConfigManagerTests/Fixtures/parsers/settings/invalid_registry_known_type/input/settings.json`
- `ClaudeConfigManagerTests/Fixtures/parsers/settings/invalid_registry_known_type/expected/parser_issues.json`
- `ClaudeConfigManager.xcodeproj/project.pbxproj`

## Key decisions and assumptions

- Added a schema-style `SettingsKeyRegistry` with per-key metadata for category, value shape, scopes, managed-only status, merge hint, and advanced/read-only diagnostics.
- Kept the existing typed `SettingsDocumentValue` named properties intact and added `registryValues` plus `rawValue(for:)` as the G1-compatible bridge toward G2 typed accessors.
- Parser type mismatches for known keys now emit `warning` severity instead of `error`, while structural shape failures such as invalid top-level objects, malformed hook family structure, or non-object family containers remain `error`.
- Registry validation currently runs generically for registry-covered keys that are not already validated by the bespoke parser helpers, to avoid duplicate diagnostics while preserving current parse behavior.
- `strictKnownMarketplaces` is modeled as a structured array, `allowedMcpServers` and `deniedMcpServers` are modeled as structured rule arrays, and `sandbox` is modeled as a nested object family.
- `pluginConfigs`, `skippedPlugins`, and `skippedMarketplaces` are registered as advanced read-only diagnostic keys and preserved in the registry-backed raw store.
- The project uses an explicit Xcode source list, so `project.pbxproj` needed a minimal source-file entry for `SettingsKeyRegistry.swift` in order for the new file to build.

## Issues encountered or open questions

- The packet spec says not to hand-edit project structure, but this repository does not auto-include new Swift files; a minimal `project.pbxproj` update was required to compile the new registry file.
- The registry intentionally favors broad-but-correct shapes for several newer families so G1 stays foundational. G2 should decide how aggressively to narrow typed accessors for those families.
- Hook actions still parse `timeoutMs` in the existing typed helper path for compatibility with current code/tests. The planning docs note a future correction toward `timeout` seconds, but that is out of scope for G1.

## Verification

- Initial required command failed because sandboxed `xcodebuild` could not write to the default DerivedData path.
- Successful full-suite run:
  - `xcodebuild -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager -configuration Debug -derivedDataPath .derivedData test CODE_SIGNING_ALLOWED=NO`

## Recommended next packet

- `G2` — Typed Accessor Layer for `SettingsDocumentValue`

# I1_FIXTURE_LAYOUT-handoff

## Complete
- Added a canonical fixture contract under `ClaudeConfigManagerTests/Fixtures` covering parser, resolver, validation, session, and shared fixture families.
- Defined deterministic naming and placement patterns using `input/` and `expected/` directories plus family-level README guidance.
- Added reusable fixture support types for tests: `FixtureCaseID`, `FixtureDescriptor`, `ExpectedSnapshotReference`, `ExpectedIssueSet`, and `FixtureLoader`.
- Added fixture contract tests to enforce required top-level families and representative parser/resolver/validation/session fixtures.
- Added shared-fixture reuse coverage by consuming `shared/settings/override_project_wins` in both parser and resolver test suites.

## Files updated
- `ClaudeConfigManagerTests/ClaudeConfigManagerTests.swift`
- `ClaudeConfigManagerTests/Parsers/SettingsParserTests.swift`
- `ClaudeConfigManagerTests/Resolver/ResolverModelsTests.swift`

## Files added
- `ClaudeConfigManagerTests/Fixtures/README.md`
- `ClaudeConfigManagerTests/Fixtures/parsers/settings/README.md`
- `ClaudeConfigManagerTests/Fixtures/parsers/settings/valid_basic/input/settings.json`
- `ClaudeConfigManagerTests/Fixtures/parsers/settings/valid_basic/expected/summary.json`
- `ClaudeConfigManagerTests/Fixtures/parsers/settings/invalid_json_trailing_comma/input/settings.json`
- `ClaudeConfigManagerTests/Fixtures/parsers/settings/invalid_json_trailing_comma/expected/parser_issues.json`
- `ClaudeConfigManagerTests/Fixtures/resolvers/settings/README.md`
- `ClaudeConfigManagerTests/Fixtures/resolvers/settings/override_project_wins/input/user.settings.json`
- `ClaudeConfigManagerTests/Fixtures/resolvers/settings/override_project_wins/input/project.settings.local.json`
- `ClaudeConfigManagerTests/Fixtures/resolvers/settings/override_project_wins/expected/resolved_snapshot.json`
- `ClaudeConfigManagerTests/Fixtures/resolvers/settings/conflict_allow_deny_overlap/input/user.settings.json`
- `ClaudeConfigManagerTests/Fixtures/resolvers/settings/conflict_allow_deny_overlap/input/project.settings.local.json`
- `ClaudeConfigManagerTests/Fixtures/resolvers/settings/conflict_allow_deny_overlap/expected/resolution_issues.json`
- `ClaudeConfigManagerTests/Fixtures/validation/settings/README.md`
- `ClaudeConfigManagerTests/Fixtures/validation/settings/permissions_allow_deny_overlap/input/settings.json`
- `ClaudeConfigManagerTests/Fixtures/validation/settings/permissions_allow_deny_overlap/expected/validation_issues.json`
- `ClaudeConfigManagerTests/Fixtures/session/README.md`
- `ClaudeConfigManagerTests/Fixtures/session/mixed_valid_invalid/input/settings.json`
- `ClaudeConfigManagerTests/Fixtures/session/mixed_valid_invalid/input/CLAUDE.md`
- `ClaudeConfigManagerTests/Fixtures/session/mixed_valid_invalid/input/.mcp.json`
- `ClaudeConfigManagerTests/Fixtures/session/mixed_valid_invalid/expected/projection_summary.json`
- `ClaudeConfigManagerTests/Fixtures/shared/settings/README.md`
- `ClaudeConfigManagerTests/Fixtures/shared/settings/override_project_wins/input/user.settings.json`
- `ClaudeConfigManagerTests/Fixtures/shared/settings/override_project_wins/input/project.settings.local.json`
- `ClaudeConfigManagerTests/Fixtures/shared/settings/override_project_wins/expected/resolved_snapshot.json`
- `Documents/I1_FIXTURE_LAYOUT-handoff.md`

## Verification
- `xcodebuild -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager -configuration Debug -derivedDataPath .derivedData test CODE_SIGNING_ALLOWED=NO`
- Result: test suite succeeded.

## Recommended next packet
- `I2_RESOLVER_TESTS`

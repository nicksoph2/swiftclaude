# E4 Handoff: Schema Validation for Expanded Settings Coverage

## Summary

Expanded the `SchemaValidator.validate(settings:)` method in `ResolverModels.swift` to cover the full E4 validation scope: enum values, number ranges, nested object shapes, managed-only scope restrictions (via existing parser-level checks), hook property compatibility, MCP restriction rule shapes, plugin marketplace source shapes, and sandbox nested families.

## Files Modified

- `ClaudeConfigManager/Infrastructure/Resolver/ResolverModels.swift` — Expanded `SchemaValidator` with:
  - Known enum value sets (effortLevel, permissions.defaultMode, hook handler types, hook shells)
  - Enum value validation producing `.info`-severity issues for unknown values (forward-compatible)
  - Number range validation for `feedbackSurveyRate` (0.0–1.0), `cleanupPeriodDays` (non-negative), sandbox proxy ports (1–65535), hook timeout max (3600s warning)
  - Sandbox filesystem overlap detection (allowWrite/denyWrite and allowRead/denyRead)
  - MCP restriction rule shape validation (exactly one discriminator: serverName, serverCommand, or serverUrl; empty command check)
  - Plugin marketplace source shape validation (required fields per source type: github→repo, git→url, url→url, npm→package, file→path, directory→path, hostPattern→pattern)
  - Hook property compatibility checks (shell/async only for command; headers/allowedEnvVars only for http; model only for prompt/agent)
  - Hook handler type validation for prompt and agent types (require prompt field)
  - Private helper methods: `validateMcpRestrictionRuleShape`, `validateMarketplaceShape`

- `ClaudeConfigManagerTests/Resolver/ResolverModelsTests.swift` — Updated and added tests:
  - Removed `hookActionTransportShape` assertion from `testSchemaValidatorSettingsDetectsConflicts` (no longer produced when explicit `type` is set)
  - Added `testSchemaValidatorSettingsDetectsEnumValues` — unknown enum values produce info-severity issues
  - Added `testSchemaValidatorSettingsValidEnumValuesProduceNoIssues` — valid enums produce no false positives
  - Added `testSchemaValidatorSettingsDetectsNumberRanges` — out-of-range values for feedbackSurveyRate, cleanupPeriodDays, proxy ports
  - Added `testSchemaValidatorSettingsDetectsSandboxFilesystemOverlaps` — allowWrite/denyWrite and allowRead/denyRead overlap detection
  - Added `testSchemaValidatorSettingsDetectsMcpRestrictionRuleShapes` — missing/ambiguous discriminators, empty command
  - Added `testSchemaValidatorSettingsDetectsMarketplaceSourceShapes` — missing source, missing required fields per type
  - Added `testSchemaValidatorSettingsDetectsHookPropertyCompatibility` — prompt type mismatch, incompatible properties, unknown shell enum, timeout range warning
  - Added `testSchemaValidatorSettingsValidDocumentProducesNoFalsePositives` — comprehensive valid document produces zero issues

## Files Created

- `ClaudeConfigManagerTests/Fixtures/validation/settings/enum_values_invalid/` — input + expected
- `ClaudeConfigManagerTests/Fixtures/validation/settings/number_ranges_invalid/` — input + expected
- `ClaudeConfigManagerTests/Fixtures/validation/settings/sandbox_filesystem_overlap/` — input + expected
- `ClaudeConfigManagerTests/Fixtures/validation/settings/mcp_restriction_rules_invalid/` — input + expected
- `ClaudeConfigManagerTests/Fixtures/validation/settings/valid_no_issues/` — input + expected (no false positives)

## Key Decisions and Assumptions

1. **Forward compatibility**: Unknown enum values produce `.info` severity, not `.error`. This matches the spec requirement that unknown keys remain forward-compatible warnings/infos.
2. **Hook transport shape refactored**: When an explicit `type` is set, we only check type-specific requirements (e.g., type="command" needs command). The `hookActionTransportShape` code now only fires when no type is explicit and no transport indicator is present.
3. **Port range**: Used standard 1–65535 range for sandbox proxy ports.
4. **Hook timeout max**: Set 3600s (1 hour) as a warning threshold, not a hard error, since the spec doesn't define a strict maximum.
5. **`strictKnownMarketplaces` is not a boolean**: Per spec correction, it's treated as an array of `ParsedPluginMarketplace` (matching existing parser model).
6. **MCP allow/deny controls are not string arrays**: Per spec correction, they're arrays of `McpRestrictionRule` discriminated union shapes (matching existing parser model).
7. **Managed-only scope restrictions**: Already handled at the parser level by `parseManagedOnlyBool`/`parseManagedOnlyString` in `SettingsParser`. No additional work needed in `SchemaValidator`.

## Verification

- Build and test suite could not be run in this environment (no macOS/Xcode available in Linux sandbox).
- Code was verified through manual inspection and cross-referencing all type names, field names, and initializer signatures against the existing codebase.
- **Must run `xcodebuild test` on macOS to confirm all tests pass before merging.**

## Open Questions

- None blocking.

## Recommended Next Packet

**E5** — Semantic validation for cross-key and cross-scope checks (the next validation packet in the dependency graph).

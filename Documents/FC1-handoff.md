# FC1 Handoff

## Files Created or Modified
- `ClaudeConfigManager/App/ClaudeConfigManagerApp.swift`
- `ClaudeConfigManager/Infrastructure/Parsers/SettingsKeyRegistry.swift`
- `ClaudeConfigManager/Infrastructure/Resolver/ResolverModels.swift`
- `ClaudeConfigManagerTests/Parsers/SettingsParserTests.swift`
- `ClaudeConfigManagerTests/Fixtures/parsers/schema-fetcher/validSchema/input/remote-schema.json`
- `ClaudeConfigManagerTests/Fixtures/parsers/schema-fetcher/validSchema/expected/parser_issues.json`
- `ClaudeConfigManagerTests/Fixtures/parsers/schema-fetcher/invalidSchema/input/invalid-schema.json`
- `ClaudeConfigManagerTests/Fixtures/parsers/schema-fetcher/invalidSchema/expected/parser_issues.json`

## What Changed
- Added FC1’s dynamic schema fetch stack:
  `SchemaRule`, `SchemaFetcher`, `SchemaFetchResult`, `SchemaComparisonResult`, `SchemaCache`, `InMemorySchemaCache`, `RemoteSchemaKey`, `SchemaFetcherPreferences`, and `SchemaFetcherService`.
- Added best-effort remote schema loading with:
  configurable URL, in-memory caching with TTL, 10 MB size guard, `$ref` rejection, nesting-depth guard, and built-in fallback on timeout/network/parse failures.
- Added a small app preferences surface in Settings:
  toggle for automatic schema updates, last-fetch timestamp, status text, and manual refresh button.
- Hooked app startup to opportunistically refresh the remote schema when the preference is enabled.
- Extended `SchemaValidator.validate(settings:schemaFetcherService:)` so unsupported top-level keys can be classified as:
  `schema.settings.schemaKnownRemoteKey` when the fetched schema knows them, or
  `schema.settings.unknownKey` when they remain truly unknown.
- Added FC1 fixture coverage and a dedicated `SchemaFetcherTests` suite inside the parser test file, covering fetch success/failure, cache behavior, merge/compare behavior, service lifecycle, and validator integration.

## Key Decisions and Assumptions
- The project’s Xcode target membership is driven by an explicit file list, so FC1 code was embedded into already-tracked Swift files instead of relying on new standalone source files being compiled automatically.
- Default fetch preference is disabled to preserve offline-safe behavior unless the user opts in.
- Built-in registry wins on rule conflicts during merge, matching the packet spec.
- The remote schema is flattened into dotted key paths for validator/service lookups; object child keys are supported, but array item paths are not separately materialized beyond item-type metadata.

## Verification
- `xcodebuild -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager -destination 'platform=macOS' -derivedDataPath .derivedData test CODE_SIGNING_ALLOWED=NO -quiet`
- `xcodebuild -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager -destination 'platform=macOS' -derivedDataPath .derivedData test CODE_SIGNING_ALLOWED=NO -only-testing:ClaudeConfigManagerTests/SchemaFetcherTests -quiet`

## Issues / Open Questions / Follow-Up Risks
- The parser still emits `preservedUnsupportedKey` based on the built-in registry. FC1 now adds schema-aware validation classification on top of that, but it does not rewrite parser-time issue generation.
- Startup refresh currently runs from the app shell without deeper projection/validation plumbing yet consuming the service automatically; later runtime packets may want to thread the shared service more broadly into session validation flows.

## Recommended Next Packet
- `T1`

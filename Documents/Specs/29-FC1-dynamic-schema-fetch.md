# Packet FC1: Dynamic Schema Fetch (Optional)

## Overview

This optional packet extends the schema validation system to fetch the settings schema from a known, configurable URL at runtime. This enables forward compatibility: if the server deploys new settings keys, the Config Manager app can recognize and display them as "schema-known but locally unrecognized" rather than treating them as unsupported unknown keys. The fetcher is best-effort: network failures or invalid schemas fall back silently to the built-in registry, ensuring the app remains functional even offline. A user preference controls whether fetching is enabled.

## Prerequisites

- Packet E4 (Schema Validation) — built-in schema registry and validation logic
- Existing `SchemaValidator` and `SchemaRule` types
- Network access (URLSession) — available on macOS
- User settings storage for preferences (existing app infrastructure)

## Files to Read Before Starting

1. `ClaudeConfigManager/Infrastructure/Resolver/ResolverModels.swift` — existing SchemaValidator
2. Preferences/settings storage mechanism in the app (if exists)
3. E4 spec (Documents/Specs/27-E4-schema-validation.md) — schema validation context

## Deliverables

### 1. SchemaFetcher (`ClaudeConfigManager/Infrastructure/Parsers/SchemaFetcher.swift`)

**Purpose**: Fetch and cache remote schema, compare with built-in registry, and integrate new keys.

**Types to create**:

- `SchemaFetcher`: Struct providing fetching and caching functionality
  - `init(schemaUrl: URL = URL(string: "https://json.schemastore.org/claude-code-settings.json")!, cache: SchemaCache = InMemorySchemaCache())` — create fetcher with configurable URL and cache
  - `func fetch(session: URLSession = .shared, timeoutSeconds: TimeInterval = 5.0) async -> SchemaFetchResult` — fetch schema, with timeout; returns result without throwing
  - `func compareWithBuiltIn(remote: [String: SchemaRule]) -> SchemaComparisonResult` — compare fetched schema to built-in registry
  - `func mergedRegistry(remote: [String: SchemaRule]) -> [String: SchemaRule]` — merge remote and built-in, built-in takes precedence in conflicts

- `SchemaFetchResult`: Enum representing fetch outcome
  - `case success(schema: [String: SchemaRule])` — successfully fetched and parsed
  - `case fallbackToBuiltIn(reason: String)` — fetch failed, using built-in schema
  - `case cachedSchema(schema: [String: SchemaRule], fetchedAt: Date)` — cache hit, no network call

- `SchemaComparisonResult`: Struct comparing remote to built-in
  - `newKeys: [String: SchemaRule]` — keys in remote but not in built-in
  - `updatedKeys: [String: SchemaRule]` — keys in both but with different rules
  - `removedKeys: [String]` — keys in built-in but not in remote
  - `summary: String` — human-readable comparison (e.g., "+5 new keys, -0 removed, ~0 updated")

- `SchemaCache`: Protocol for caching strategies
  - `func get(key: String) -> ([String: SchemaRule], Date)?` — retrieve cached schema and fetch time
  - `func set(key: String, schema: [String: SchemaRule], fetchedAt: Date)` — store schema in cache
  - `func invalidate(key: String)` — clear cache entry

- `InMemorySchemaCache`: Struct conforming to SchemaCache
  - Stores schema in memory with fetch timestamp
  - Optional TTL-based expiration (e.g., cache valid for 24 hours)
  - `func isExpired(fetchedAt: Date, ttl: TimeInterval = 86400) -> Bool` — check if cache is stale

- `RemoteSchemaKey`: Struct for JSON schema representation from remote
  - `type: String` — JSON type name
  - `enum: [String]?` — allowed enum values, if applicable
  - `pattern: String?` — regex pattern for strings
  - `minLength: Int?`, `maxLength: Int?` — string length constraints
  - `minimum: Double?`, `maximum: Double?` — numeric range constraints
  - `items: RemoteSchemaKey?` — for array item schema
  - `properties: [String: RemoteSchemaKey]?` — for object nested schema
  - `required: Bool?` — if key is required
  - `description: String?` — human-readable description

**Integration points**:
- `SchemaValidator` is extended to optionally use merged registry instead of built-in
- Fetch happens at app startup or on user request (not per-validation call)
- `SchemaFetcher` is thread-safe for async/await usage
- Results stored in AppPreferences or equivalent
- network fetching remains optional and must never block local parsing or read-only inspection

**Edge cases to handle**:
- Network timeout or unreachable URL — fallback silently, log warning
- Invalid JSON response — fallback silently, log error
- Parsing error (remote schema doesn't match expected structure) — fallback silently, log error
- Cache valid but no internet — use cache; alert user it's stale (optional)
- Very large schema (>10MB) — reject, fallback to built-in, log error
- Malicious schema (circular references, extremely deep nesting) — reject, fallback

### 2. SchemaFetcherService (`ClaudeConfigManager/Infrastructure/Parsers/SchemaFetcherService.swift`)

**Purpose**: Manage fetching lifecycle, user preferences, and integration with validation.

**Types to create**:

- `SchemaFetcherService`: Actor for thread-safe schema management
  - `init(schemaFetcher: SchemaFetcher = SchemaFetcher(), preferences: AppPreferences)` — initialize with fetcher and prefs
  - `var isFetchingEnabled: Bool { get set }` — user pref for enabling fetches
  - `var lastFetchedAt: Date? { get }` — timestamp of last successful fetch
  - `var currentMergedRegistry: [String: SchemaRule] { get }` — active registry (merged or built-in)
  - `func refreshSchema() async -> SchemaFetchResult` — initiate fetch, update merged registry, return result
  - `func getRule(for keyPath: String) -> SchemaRule?` — retrieve rule from merged registry
  - `func newKeysDetected() -> [String: SchemaRule]` — keys added since last build (for UI display)

- `SchemaFetcherPreferences`: Struct for user preferences
  - `isEnabled: Bool` — whether fetching is allowed
  - `autoRefreshInterval: TimeInterval?` — hours between auto-fetches (optional, e.g., 24)
  - `lastFetchedAt: Date?` — timestamp of last successful fetch
  - `cacheSchema: Bool` — whether to cache fetched schema

**Integration points**:
- `SchemaValidator` calls `SchemaFetcherService.getRule()` instead of accessing static registry directly
- App initialization or AppDelegate can call `SchemaFetcherService.refreshSchema()` if enabled
- Preferences stored in UserDefaults or app-specific preferences
- Service is an actor for thread-safe usage across async operations

**Edge cases to handle**:
- User disables fetching mid-session — continue using current merged registry, don't refresh
- Fetch succeeds after previous failures — update merged registry, alert user
- Merge conflict (same key, different rules) — built-in wins, new rule marked as "remotely updated"

### 3. Modifications to `ResolverModels.swift` — SchemaValidator Integration

**What changes**:
- `SchemaValidator` methods accept optional `schemaFetcherService: SchemaFetcherService?` parameter
- If service is provided and has merged registry, use merged rules instead of static registry
- If service is not provided, use built-in registry (backward compatible)
- Unknown keys flagged by fetched schema are marked differently (info level) than truly unknown keys

**What must NOT change**:
- Default behavior when SchemaFetcherService is nil — uses built-in registry

### 4. UI Preference View (Optional)

**Purpose**: Allow user to enable/disable dynamic schema fetching.

**Types to create** (if implementing UI):

- `SchemaFetcherPreferencesView`: SwiftUI view (optional)
  - Toggle: "Allow automatic schema updates"
  - Info text: "When enabled, the app will check for new settings keys from the server."
  - Last fetch time: "Last updated: [timestamp]"
  - Manual refresh button: "Refresh Now"
  - Status indicator: green checkmark for successful fetch, red X for failed, gray for not yet fetched

**Integration points**:
- Embedded in app settings/preferences screen
- Calls `SchemaFetcherService.refreshSchema()` on "Refresh Now" button

## Test Specification

### Test File: `ClaudeConfigManagerTests/Parsers/SchemaFetcherTests.swift`

**Test cases**:

1. `testFetch_ValidUrl_Success`: Mock URLSession with valid schema JSON, call fetch, expect success result with parsed schema.

2. `testFetch_InvalidUrl_FallbackToBuiltIn`: Mock URLSession with 404 error, call fetch, expect fallbackToBuiltIn result.

3. `testFetch_TimeoutExceeded_FallbackToBuiltIn`: Mock URLSession with timeout error, call fetch, expect fallbackToBuiltIn with timeout reason.

4. `testFetch_InvalidJsonResponse_FallbackToBuiltIn`: Mock URLSession with non-JSON response, call fetch, expect fallbackToBuiltIn.

5. `testFetch_LargeSchema_Rejected_FallbackToBuiltIn`: Mock URLSession with schema > 10MB, call fetch, expect fallbackToBuiltIn with size reason.

6. `testCompare_NewKeysDetected_Included`: Built-in has 50 keys, remote has 55 (5 new), call compare, expect newKeys count is 5.

7. `testCompare_RemovedKeys_Detected`: Built-in has 50 keys, remote has 45, call compare, expect removedKeys count is 5.

8. `testCompare_UpdatedKeys_Detected`: Same key exists in both, but rule changed (e.g., allowedValues list differs), expect updatedKeys includes key.

9. `testMerge_RemoteAndBuiltIn_BuiltInWins`: Same key in both with different rules, call merge, expect built-in rule is returned.

10. `testMerge_NewKeyIncluded_InMerged`: Key only in remote, call merge, expect included in merged registry.

11. `testCache_Hit_ReturnsCachedSchema`: Store schema in cache, fetch again, expect cacheSchemaResult with same schema.

12. `testCache_Expired_FetchesFresh`: Cache TTL is 1 second, wait 2 seconds, call fetch, expect fresh fetch despite cache (no mock network call).

13. `testInMemoryCache_SetAndGet_Retrieves`: Store key-value in cache, get, expect value and fetch time returned.

14. `testInMemoryCache_Invalidate_Clears`: Store, invalidate, get, expect nil returned.

15. `testService_IsFetchingEnabled_Respected`: Disable fetching in service, call refresh, expect fallbackToBuiltIn without making network call.

16. `testService_LastFetchedAt_Updated`: Call refresh successfully, expect lastFetchedAt is approximately now.

17. `testService_CurrentMergedRegistry_ContainsNewKeys`: After successful fetch with new keys, expect merged registry includes new keys.

18. `testService_NewKeysDetected_ReturnsNewOnly`: Merged registry has 5 new keys since last built-in update, call newKeysDetected, expect returns those 5.

### Test Fixtures

For test fixtures, create mock responses and schema JSON:

**Path**: `ClaudeConfigManagerTests/Fixtures/parsers/schema-fetcher/validSchema/input/`

- `remote-schema.json`:
```json
{
  "type": "object",
  "properties": {
    "model": {
      "type": "string",
      "enum": ["claude-opus", "claude-3-5", "gpt-4", "new-model-v2"],
      "description": "AI model to use"
    },
    "newKey": {
      "type": "boolean",
      "description": "New setting from server"
    }
  }
}
```

**Path**: `ClaudeConfigManagerTests/Fixtures/parsers/schema-fetcher/invalidSchema/input/`

- `invalid-schema.json`:
```json
{ not valid json }
```

## Acceptance Criteria

1. `SchemaFetcher` struct exists with fetch and compare methods.
2. `SchemaFetchResult` enum captures success, fallback, and cache outcomes.
3. `SchemaComparisonResult` identifies new, updated, and removed keys.
4. `SchemaCache` protocol allows pluggable caching strategies.
5. `InMemorySchemaCache` implements caching with optional TTL.
6. Network timeouts and errors are handled gracefully; app falls back to built-in.
7. Invalid or malicious schemas are rejected; app continues with built-in.
8. Schema size limit (e.g., 10MB) is enforced; oversized schemas rejected.
9. `SchemaFetcherService` manages fetching lifecycle and user preferences.
10. Service is thread-safe (actor-based or synchronization primitives).
11. Merged registry integrates new keys while preserving built-in rules.
12. Unknown keys from fetched schema are marked as "schema-known" (info level).
13. User preference allows enabling/disabling fetches.
14. Manual refresh button works in UI.
15. Last fetch timestamp is tracked and displayed.
16. All tests pass; no crashes on network errors or malformed input.

## Out of Scope

- Automatic background refresh (manual refresh only in this packet)
- Delta updates (full schema always fetched)
- Schema versioning or deprecation notices
- Per-key update explanations or release notes
- Validating fetched schema against JSON Schema standard

## Build Verification

```bash
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager -destination 'platform=macOS' -quiet 2>&1 | grep -E "(test|PASS|FAIL)"
```

Expected: All SchemaFetcherTests pass; network mocks work correctly.

## Handoff Notes Template

After completing this packet, create `Documents/FC1-handoff.md` with:

```markdown
# FC1 Handoff

## Files Created
- ClaudeConfigManager/Infrastructure/Parsers/SchemaFetcher.swift
- ClaudeConfigManager/Infrastructure/Parsers/SchemaFetcherService.swift
- (Optional) ClaudeConfigManager/Features/Preferences/SchemaFetcherPreferencesView.swift

## Files Modified
- ClaudeConfigManager/Infrastructure/Resolver/ResolverModels.swift
  - Updated SchemaValidator to accept optional SchemaFetcherService
  - Modified getRule methods to use merged registry if service provided

## Key Decisions
- Best-effort fetching: network failures don't break app.
- Built-in rules always win in merge (stability over novelty).
- Fetching is optional and disabled by default (opt-in).
- In-memory cache with TTL-based expiration.
- Unknown keys from remote schema marked as "schema-known" (info level).

## Issues Encountered
(none expected)

## Recommended Next Packet
(none) — FC1 is optional and terminal. All critical functionality complete with E5.
```

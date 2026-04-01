# D3 Settings Merge Rules - Handoff

## Completed
- Implemented per-key merge behavior in `SettingsResolver.buildSnapshot(from:)`.
- Kept precedence selection (`resolvePrecedence`) separate from merge execution.
- Added explicit merge routing by key family:
  - scalar `replace`
  - object `deepMergeObject` (`env`, `attribution`)
  - list `appendUnique` (`allowedHttpHookUrls`, `httpHookAllowedEnvVars`)
  - `permissions` special merge (`allow`/`deny` append+dedupe, `mode` replace, overlap conflict issue)
  - `hooks` keyed merge by event with action append+dedupe and shape-conflict diagnostics
  - `passthrough` fallback for unsupported keys
- Added canonical JSON fingerprinting for deterministic array/action de-duplication.
- Added type-mismatch and unresolved merge diagnostics where participants are incompatible.

## Tests added/updated
- Updated scalar snapshot test to assert `.replace`.
- Added merge tests for:
  - `env` deep merge
  - `allowedHttpHookUrls` append+dedupe
  - `permissions` merge + allow/deny overlap conflict
  - `hooks` merge + action dedupe
  - object-shape mismatch fallback to lower-precedence usable source

## Verification
- Ran:
  - `xcodebuild -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager -configuration Debug -derivedDataPath .derivedData test CODE_SIGNING_ALLOWED=NO`
- Result: `TEST SUCCEEDED`.

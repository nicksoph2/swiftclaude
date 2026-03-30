# Packet D3 - Settings Merge Rules

## Goal
Define and implement deterministic per-key merge behavior for settings resolution after `D2` precedence/source selection has produced ordered candidates and per-key participants.

## Why this packet exists
`D2` determines source authority; it does not define how multi-source values combine for object and collection keys. This packet defines merge policy per key family so resolver output is explainable, testable, and stable.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/AI_DRAFT_OTHERS_HANDOFF.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_D_RESOLVER.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D1_RESOLVER_MODELS.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D2_SETTINGS_PRECEDENCE.md`
- parsed settings structures from `C1_SETTINGS_JSON_PARSER`

## Dependencies
- `C1_SETTINGS_JSON_PARSER`
- `D1_RESOLVER_MODELS`
- `D2_SETTINGS_PRECEDENCE`

## Deliverables
- key-family merge rule registry consumed by `SettingsResolver`
- merge stage that consumes `ResolvedSettingsSourceSelection` from `D2`
- per-key merged effective values with merge-method provenance
- conflict/shape diagnostics for unmergeable contributions
- deterministic resolver tests for scalar/object/collection/special-case behavior

## Required behavior
### Stage separation
- keep precedence selection and merge as separate resolver stages
- consume ordered candidates and per-key participants from `D2`
- do not re-rank source priority in `D3`

### Merge rule registry
- define one explicit rule per supported settings key family
- keep rule mapping centralized (not scattered in conditional branches)
- preserve deterministic fallback behavior for unknown keys

### Canonical key-family merge matrix
Apply the following merge methods.

1. `replace` (scalar override by highest-precedence usable value)
- `$schema`
- `apiKeyHelper`
- `autoMemoryDirectory`
- `cleanupPeriodDays`
- `companyAnnouncements`
- `includeCoAuthoredBy`
- `includeGitInstructions`
- `autoMode`
- `disableAutoMode`
- `useAutoModeDuringPlan`
- `disableDeepLinkRegistration`
- `allowManagedHooksOnly`

2. `deepMergeObject` (key-wise object merge with higher-precedence child keys winning)
- `env`
- `attribution`

3. `appendUnique` (ordered concatenation + de-duplication)
- `allowedHttpHookUrls`
- `httpHookAllowedEnvVars`

4. `deepMergeObject` + nested array policy for `permissions`
- object-level merge for `permissions`
- nested rule for `permissions.allow`: `appendUnique`
- nested rule for `permissions.deny`: `appendUnique`
- nested rule for `permissions.mode`: `replace`

5. `keyedByIdentifier` + nested append policy for `hooks`
- merge `hooks` by stable event identifier (event key)
- for each merged event, combine action lists by ordered append
- de-duplicate actions by stable action identity (canonical action payload fingerprint)
- when event shapes are incompatible across participants, emit conflict issues and apply deterministic fallback

6. `passthrough` for unsupported/forward-compatible top-level keys
- preserve key/value from the highest-precedence usable participant
- attach note/issue metadata indicating unsupported merge semantics

### Permissions-related merge interpretation
- `permissions.allow` and `permissions.deny` are additive lists with de-duplication
- merged lists preserve first-seen order by precedence participation order
- when the same permission pattern exists in both merged `allow` and merged `deny`, keep both in raw merged output and emit a conflict/note for interpretation visibility
- `permissions.mode` remains scalar override and does not concatenate

### Hooks-related merge interpretation
- treat hooks as structured, not raw string arrays
- merge by event key first; then merge event actions by append + deterministic de-duplication
- preserve per-action provenance where feasible for Session inspection
- propagate parser/resolution issues for invalid hook entries instead of dropping silently

### Conflict and shape handling
- incompatible type contributions for a mergeable key emit `ResolutionIssue` with source attribution
- invalid/missing/inaccessible participants remain in trace and diagnostics
- merge should continue with remaining usable participants when possible
- if no usable participant remains for a key, emit unresolved result with explicit note/issue

### Provenance requirements per resolved key
Each resolved settings key entry should include:
- effective merged value
- winning source for the resulting key (or selected dominant contributor when merged)
- participants in deterministic order
- overridden/ignored contributors where applicable
- merge method used
- attached issues and notes

### Determinism requirements
- fixed merge rule mapping by key family
- stable participant iteration order inherited from `D2`
- stable de-dup identity for collection entries
- stable ordering of merged object keys and output entries for tests/snapshots

## Suggested Swift types
- `SettingsMergeRule`
- `SettingsMergeRuleRegistry`
- `SettingsMergeEngine`
- `SettingsMergeContext`
- `SettingsMergeResult`
- `ResolvedSettingsSnapshot`
- `ResolvedSettingsEntry`
- `ResolutionIssue`
- `MergeMethod`

## Suggested implementation notes (non-binding)
- extend `SettingsResolver` with a dedicated merge stage after `resolvePrecedence`
- keep the existing `ResolvedSettingsSourceSelection` as input contract for the merge stage
- map top-level key path to merge family via registry lookup
- implement nested-key policies for `permissions` and `hooks` explicitly, not implicitly
- preserve unknown keys via `passthrough` for forward compatibility

## Test fixture guidance
Add resolver tests for at least:
- scalar replace across full source chain
- `env` deep merge with overlapping child keys
- `attribution` object merge with partial keys
- `allowedHttpHookUrls` append + de-dup ordering
- `httpHookAllowedEnvVars` append + de-dup ordering
- `permissions` merge with allow/deny/mode across multiple sources
- `permissions` allow-vs-deny overlap conflict note/issue
- `hooks` event merge with multi-source participation
- `hooks` action de-dup behavior and shape conflicts
- unmergeable type mismatch fallback for object/array families
- unsupported top-level key passthrough behavior
- deterministic ordering in merged snapshot output

## Acceptance criteria
- every supported settings key family resolves with an explicit, testable merge method
- merged settings output includes provenance + merge-method attribution per key
- conflicts and shape mismatches are surfaced as deterministic, attributable issues
- precedence-stage responsibilities remain isolated from merge-stage logic

## Out of scope
- broad precedence ladder definition (`D2`)
- Session UI rendering and formatting
- schema/semantic policy decisions owned by Section E
- file write-back rendering and save behavior

## Done when
- `SettingsResolver` can produce merged effective settings with per-key merge provenance
- resolver tests demonstrate deterministic behavior for scalar/object/collection/special-case keys
- `D7_SESSION_PROJECTION` can consume merged settings output without re-applying merge logic

## Suggested next packet
- `D4_INSTRUCTION_RESOLUTION`

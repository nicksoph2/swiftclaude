# R1 Handoff — Settings Resolver for Expanded Key Families

## Packet Summary

Wired the expanded settings surface (from G1/G2, P1/P2, S1–S4, U1/U2, and managed-tier packets) through the `SettingsResolver` so that Session views can display effective values with correct precedence, provenance, and merge behavior. The resolver now consults the `SettingsKeyRegistry` for merge rules instead of hardcoded key sets.

---

## Files Modified

### `ClaudeConfigManager/Infrastructure/Resolver/ResolverModels.swift`

- **Added** stored property `private let registry: SettingsKeyRegistry` and `init(registry:)` with default `.shared` to `SettingsResolver`
- **Removed** hardcoded merge rule sets (`replaceKeys`, `deepMergeObjectKeys`, `appendUniqueKeys`)
- **Replaced** `mergeRule(for:)` with registry-driven lookup: checks `permissions`/`hooks` special cases first, then consults `registry.definition(for:)` and maps `MergeMethod` → `SettingsMergeRule`
- **Added** `mapMergeHint(_:)` static method for `MergeMethod` → `SettingsMergeRule` conversion
- **Enhanced** `buildSnapshot` to:
  - Add provenance notes when managed policy overrides lower-scope values ("Managed policy is active for '<key>'; lower-scope values are ineffective.")
  - Emit `.conflict` warning issues when managed-only keys appear in non-managed scopes
  - Add snapshot-level note when any managed candidate is present

### `ClaudeConfigManagerTests/Resolver/ResolverModelsTests.swift`

- **Added** 10 new test methods covering R1 requirements:
  1. `testSettingsResolverUsesRegistryMergeHintForScalarKeys` — ~20 scalar keys get `.replace`
  2. `testSettingsResolverUsesRegistryMergeHintForDeepMergeObjectKeys` — sandbox, worktree, statusLine, etc. get `.deepMergeObject`
  3. `testSettingsResolverUsesRegistryMergeHintForAppendUniqueArrayKeys` — companyAnnouncements, claudeMdExcludes, etc. get `.appendUnique`
  4. `testSettingsResolverManagedPolicyMakesLowerScopeValuesIneffective` — provenance notes on managed override
  5. `testSettingsResolverManagedOnlyKeyInNonManagedScopeEmitsWarning` — warnings for managed-only keys in user scope
  6. `testSettingsResolverManagedOnlyKeyFromManagedScopeDoesNotWarn` — negative test
  7. `testSettingsResolverPluginAndMarketplaceKeysUseMergeHintsFromRegistry` — enabledPlugins, extraKnownMarketplaces
  8. `testSettingsResolverMcpControlKeysResolveCorrectly` — MCP control keys
  9. `testSettingsResolverUnknownKeyFallsToPassthrough` — unknown keys get passthrough
  10. `testSettingsResolverAllRegistryKeysHaveExplicitMergeMethod` — comprehensive coverage check

---

## Key Decisions and Assumptions

1. **Registry is authoritative for merge behavior.** The resolver now delegates merge rule selection to `SettingsKeyRegistry.definition(for:).mergeHint` rather than maintaining its own lists. This means if the registry says `companyAnnouncements` is `.appendUnique`, the resolver follows that — even though the old hardcoded set treated it as `.replace`.

2. **Special handling preserved for `permissions` and `hooks`.** These two key families need custom merge logic (structural merging with nested arrays/objects) that goes beyond what a simple `MergeMethod` enum can express. The resolver checks for these before consulting the registry.

3. **`mapMergeHint` collapses some distinctions.** `selectHighestPrecedence` and `replace` both map to `.replace`. `append`, `appendUnique`, and `setUnion` all map to `.appendUnique`. `keyedByIdentifier` maps to `.hooks` (the existing keyed-merge codepath). If finer-grained array merge semantics are needed later, the `SettingsMergeRule` enum and its merge implementation would need to be extended.

4. **Backward-compatible init.** `SettingsResolver()` continues to work because `init(registry:)` defaults to `.shared`. No existing call sites need updating.

5. **Managed provenance notes are additive.** They appear in the `ResolutionTrace.notes` array alongside existing notes, not replacing them. This ensures UI can display all context.

6. **Managed-only warnings use `.conflict` code.** The `ResolutionIssue.Code` enum already has `.conflict` which is the closest semantic match for "key appears where it shouldn't." A dedicated `.managedOnlyViolation` code could be added later if needed.

---

## Issues Encountered

1. **No Xcode in CI/sandbox.** The Linux sandbox does not have `xcodebuild`, so the full test suite could not be run during implementation. **Tests must be verified on macOS before merging.**

2. **No new fixture files added.** The R1 spec mentioned fixtures under `Fixtures/resolvers/settings/`, but the new tests are self-contained (they construct resolver inputs programmatically). Fixture-based tests can be added in R2/R3 if needed for more complex multi-scope scenarios.

---

## Open Questions

1. **Should `append` vs `appendUnique` vs `setUnion` have distinct resolver behaviors?** Currently they all map to `.appendUnique`. If the distinction matters (e.g., `append` allows duplicates, `setUnion` ignores order), the `SettingsMergeRule` enum needs new cases and the merge implementation needs updating.

2. **Should managed-only key warnings be `.warning` or `.error` severity?** Currently `.warning`. If the intent is to hard-block non-managed sources from contributing managed-only keys, this should be `.error`.

3. **`companyAnnouncements` merge behavior changed.** The old hardcoded set had it as `.replace`; the registry says `.appendUnique`. This is intentional (registry is authoritative), but verify this matches product intent.

---

## Recommended Next Packet

**R2: MCP + Agent + Skill Resolver** — The `MCPResolver`, `AgentResolver`, and `SkillResolver` stubs in `ResolverModels.swift` need the same registry-driven treatment. R2 can follow the same pattern established here: consult a registry/definition for merge behavior, add provenance notes, and emit issues for scope violations.

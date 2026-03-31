# E5 Handoff: Semantic Validation for New Interactions

## Summary

Extended the semantic validation layer to cover the Packet E5 interaction set after schema validation:

- hooks configured but neutralized by `disableAllHooks` or `allowManagedHooksOnly`
- managed-only settings whose lower-scope values are ineffective because managed policy wins
- resolved permissions allow/deny contradictions
- resolved MCP allow/deny rule contradictions
- sandbox-disabled configurations that leave nested sandbox settings ineffective
- MCP servers blocked by deny rules or managed-only MCP policy

## Files Modified

- `ClaudeConfigManager/Infrastructure/Resolver/ResolverModels.swift`
- `ClaudeConfigManagerTests/Resolver/ResolverModelsTests.swift`

## Key Decisions and Assumptions

- Reused the existing `SemanticValidator` rather than introducing a separate validation engine, since the repo already centralizes semantic rules there.
- Extended `SemanticValidationContext` with resolved `settings` and `hooks` snapshots so E5 rules can reason across scopes and policy consequences without changing parser behavior.
- Kept the packet scoped to diagnostics; no resolver merge semantics were changed for managed-only keys.
- Used resolver-backed consequence messaging that describes what will actually happen to the user-facing configuration, especially for managed precedence and hook/MCP suppression.

## Verification

- `xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager -destination 'platform=macOS' -quiet`
  - This failed in the sandbox because Xcode could not write to default DerivedData under `~/Library`.
- `xcodebuild -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager -configuration Debug -derivedDataPath .derivedData test CODE_SIGNING_ALLOWED=NO`
  - Passed

## Open Questions / Risks

- Managed-only keys are still surfaced via the current resolver merge behavior; E5 now explains when lower-scope values are ineffective, but the underlying merged display model may still deserve a future resolver/UI refinement if product wants the effective value itself to hide those lower-scope contributions.

## Recommended Next Packet

- `FC1` if optional forward-compatibility work is still desired; otherwise the validation track is complete and the next priority should come from the runtime/observability track (`T1`).

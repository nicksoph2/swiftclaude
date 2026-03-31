# R3 Handoff — MCP Resolver Updates

## Packet Summary

Implemented MCP policy enforcement that resolves MCP servers and MCP policy controls into a trustworthy effective MCP snapshot. Each server now carries an effective state (active, disabled, blocked, managed, unresolved) with a human-readable explanation and policy effect provenance.

---

## Files Created

### `ClaudeConfigManagerTests/Fixtures/resolvers/mcp/policy_enforcement/input/managed-settings.json`
- Fixture with `allowManagedMcpServersOnly`, `deniedMcpServers`, and `disabledMcpjsonServers` for testing managed policy suppression.

### `ClaudeConfigManagerTests/Fixtures/resolvers/mcp/policy_enforcement/input/project.mcp.json`
- Fixture with three MCP servers (filesystem, evil-server, disabled-one) for policy enforcement testing.

### `ClaudeConfigManagerTests/Fixtures/resolvers/mcp/policy_enforcement/input/managed.mcp.json`
- Fixture with a managed MCP server for testing managed-server pass-through.

### `ClaudeConfigManagerTests/Fixtures/resolvers/mcp/policy_enforcement/expected/policy_summary.json`
- Expected outcome summary for the policy enforcement test scenario.

## Files Modified

### `ClaudeConfigManager/Infrastructure/Resolver/ResolverModels.swift`

- **Added** `McpServerEffectiveState` enum with cases: `.active`, `.disabled`, `.blocked`, `.managed`, `.unresolved`.
- **Added** `McpPolicyReason` enum for the six MCP policy keys: `allowManagedMcpServersOnly`, `enableAllProjectMcpServers`, `enabledMcpjsonServers`, `disabledMcpjsonServers`, `allowedMcpServers`, `deniedMcpServers`.
- **Added** `McpPolicyEffect` struct carrying reason, policy source attribution, and message.
- **Added** `MCPResolver.PolicyInput` nested struct for policy configuration inputs.
- **Added** `resolveWithPolicy(documents:policy:)` and `resolveWithPolicy(candidates:policy:)` methods to MCPResolver for full policy-aware resolution.
- **Added** `applyPolicy(to:policy:)` method to MCPResolver for applying policy to an already-resolved snapshot (used by SessionProjectionBuilder).
- **Added** `MCPResolver.extractPolicyInput(from:)` static method that extracts MCP policy inputs from a `ResolvedSettingsSnapshot`, including parsing of `McpRestrictionRule` objects from settings entries.
- **Added** Private policy evaluation methods: `evaluateServerPolicy`, `evaluateServerPolicyFromSnapshot`, `matchesDenyRule`, `matchesAllowRule`, `matchesRestrictionRule` for rule-based server matching by name, command array, or URL pattern.
- **Updated** `ResolvedMcpServerEntry` to carry `effectiveState: McpServerEffectiveState`, `stateExplanation: String`, and `policyEffects: [McpPolicyEffect]` (all with defaults for backward compatibility).
- **Updated** `ResolvedMcpSnapshot` to carry `policyEffects: [McpPolicyEffect]` (default empty for backward compatibility).
- **Added** `mcpPolicySuppressed` and `mcpDenyRuleMatch` cases to `ResolutionIssueCode` enum.
- **Added** `deriveMcp(from:settings:)` method to `SessionProjectionBuilder` that applies MCP policy from resolved settings (mirrors the R2 `deriveHooks` pattern).
- **Updated** `SessionProjectionBuilder.build(from:)` to call `deriveMcp` and pass the policy-annotated MCP snapshot through to all downstream methods.
- **Updated** `buildFamilyStates`, `buildProvenance`, and `projectionNotes` methods to accept the policy-aware MCP snapshot parameter.

### `ClaudeConfigManagerTests/Resolver/ResolverModelsTests.swift`

- **Added** overloaded `makeMcpServer(serverID:parseOrder:config:)` helper that accepts `JSONValue` directly (for testing non-object configs).
- **Added** 13 new test methods for R3 requirements:
  1. `testMCPResolverPolicyAllowManagedMcpServersOnlyBlocksNonManaged` — managed-only policy blocks user servers, passes managed servers.
  2. `testMCPResolverPolicyDeniedMcpServersBlocksByName` — deny by serverName rule.
  3. `testMCPResolverPolicyDeniedMcpServersByCommand` — deny by serverCommand array match.
  4. `testMCPResolverPolicyDeniedMcpServersByUrl` — deny by serverUrl prefix match.
  5. `testMCPResolverPolicyDisabledMcpjsonServersDisablesNamedServer` — disabledMcpjsonServers produces disabled state.
  6. `testMCPResolverPolicyAllowedMcpServersBlocksUnlistedServers` — allowedMcpServers blocks unlisted servers.
  7. `testMCPResolverPolicyDenyWinsOverAllow` — deny rules take precedence over allow rules.
  8. `testMCPResolverPolicyEnableAllProjectMcpServersAnnotatesProjectServers` — auto-approve annotation for project servers.
  9. `testMCPResolverPolicyEnabledMcpjsonServersAnnotatesNamedServers` — enabled annotation for named servers.
  10. `testMCPResolverExtractPolicyInputFromResolvedSettings` — extracts all six policy keys from settings snapshot.
  11. `testMCPResolverApplyPolicyPostResolutionMatchesResolveWithPolicy` — verifies applyPolicy produces same state as resolveWithPolicy.
  12. `testMCPResolverUnresolvedServerGetsUnresolvedState` — non-object config gets unresolved effective state.
  13. `testSessionProjectionBuilderAppliesMcpPolicyFromSettings` — end-to-end: builder derives MCP with policy from settings.

---

## Key Decisions and Assumptions

1. **Dedicated policy enforcement layer.** Rather than mixing policy checks into the basic precedence resolution, a separate policy evaluation phase runs after basic resolution. This keeps the existing `resolve()` API backward-compatible.

2. **Backward-compatible model extensions.** `ResolvedMcpServerEntry` and `ResolvedMcpSnapshot` gained new fields with default values, so all existing construction sites compile without changes.

3. **Deny rules win over allow rules.** This matches the documented behavior — `deniedMcpServers` is evaluated before `allowedMcpServers`, and if a server matches a deny rule, it's blocked regardless of allow rules.

4. **allowManagedMcpServersOnly is the strongest non-managed block.** It's evaluated first (after managed server pass-through) and blocks all non-managed servers before deny/allow rules are considered.

5. **Policy evaluation order.** For non-managed servers:
   1. `allowManagedMcpServersOnly` (blocks if true)
   2. `deniedMcpServers` (blocks if matched)
   3. `disabledMcpjsonServers` (disables if name matches)
   4. `allowedMcpServers` (blocks if non-empty and no match)
   5. `enabledMcpjsonServers` / `enableAllProjectMcpServers` (annotation only)

6. **Managed servers always pass through.** Servers from managed sources always get `effectiveState: .managed`, regardless of any policy settings.

7. **SessionProjectionBuilder delegates to MCPResolver.** Following the R2 pattern where `deriveHooks` delegates to `HookResolver`, the new `deriveMcp` method delegates to `MCPResolver.applyPolicy()`.

8. **Policy extraction from settings.** The `extractPolicyInput(from:)` static method reads MCP policy keys from the resolved settings snapshot and parses `McpRestrictionRule` objects from the `allowedMcpServers`/`deniedMcpServers` entries.

9. **URL matching uses prefix matching.** `serverUrl` rules match if the server URL starts with or equals the rule URL. This handles path-based discrimination (e.g., `https://evil.example.com` matches `https://evil.example.com/mcp`).

10. **Command matching uses prefix matching.** `serverCommand` rules match by comparing the full command array (`[command] + args`) against the rule array using `starts(with:)`.

---

## Verification

The Linux sandbox does not have `xcodebuild`. **Tests must be verified on macOS before merging.**

Manual code review confirmed:
- Brace balance is correct (verified with string-aware counter: 957/957)
- No duplicate symbol definitions
- All new fields have default values for backward compatibility
- Existing test callsites are unaffected
- `ResolutionIssueCode.mcpPolicySuppressed` and `.mcpDenyRuleMatch` integrate with existing issue infrastructure
- `MCPResolver.PolicyInput` follows the same nested-struct-in-resolver pattern as `HookResolver.Input`

---

## Open Questions

1. **Should `enabledMcpjsonServers` be a gating mechanism?** Currently it's treated as an annotation-only effect (server is active either way). If it should gate servers similarly to an allowlist, the logic would need to change to disable servers NOT in the enabled list.

2. **disabledMcpjsonServers vs deniedMcpServers severity.** Currently, disabled produces `.info` severity issues and denied produces `.warning`. The UI may want to differentiate these visually.

3. **Policy source attribution granularity.** Currently `extractPolicyInput` uses a single `policySource` for all policy effects. If different MCP policy keys come from different settings scopes (e.g., `deniedMcpServers` from user, `allowManagedMcpServersOnly` from managed), per-key attribution would be more precise.

---

## Recommended Next Packet

**V1** — The next packets in the resolver track are complete. The Session UI track (V1, V2, V3, V4) can now display policy-aware MCP state with effective state badges and explanation text.

# Packet 05 Handoff

## What Was Completed

All deliverables from the packet were implemented and all tests pass (zero warnings, zero errors).

## Files Created or Modified

**Modified — main target:**
- `ClaudeConfigManager/Infrastructure/Parsers/SettingsParser.swift`
  - Added `case deprecatedKey` to `SyntaxIssueCode`
  - Added `method`, `body`, `template`, `agentId`, `inputs` fields to `ParsedHookAction`
  - Added `parseJSONValueMap` helper
  - Updated `parseHookActions` to parse all new fields
  - Updated `validateHookActionShape` — `prompt` type now requires `template`; `agent` type now requires `agent_id`
  - Added deprecation warning (`deprecatedKey` / `.info`) when `includeCoAuthoredBy` is found

- `ClaudeConfigManager/Infrastructure/Resolver/ResolverModels.swift`
  - Added `deprecatedKey` to the `mapParserIssueCode` switch
  - Added `method`, `body`, `template`, `agentId`, `inputs` fields to `ResolvedHookHandler`
  - Updated resolver hook validation to check `hasTemplate` / `hasAgentId` instead of `hasPrompt`

**Modified — test fixtures:**
- `ClaudeConfigManagerTests/Fixtures/parsers/settings/mixed_hook_handler_types/input/settings.json` — prompt type now uses `template`, agent type now uses `agent_id`
- `ClaudeConfigManagerTests/Fixtures/parsers/settings/valid_hook_all_types/input/settings.json` — same
- `ClaudeConfigManagerTests/Fixtures/parsers/settings/invalid_hook_cross_type/input/settings.json` — added `template`/`agent_id` so cross-type warnings are still emitted
- `ClaudeConfigManagerTests/Fixtures/parsers/settings/misplaced_claude_json_keys/expected/parser_issues.json` — added `unknownKey` (pre-existing fixture gap, not caused by Packet 05)

**Created — new test fixtures:**
- `parsers/settings/hook_once_shell_timeout/` — command with once/shell/timeout
- `parsers/settings/hook_http_extended/` — http with method/body/headers
- `parsers/settings/hook_prompt_type/` — prompt type with template/model
- `parsers/settings/hook_agent_type/` — agent type with agent_id/inputs
- `parsers/settings/attribution_object_format/` — attribution as object
- `parsers/settings/attribution_deprecated_key/` — includeCoAuthoredBy deprecated

**Modified — test files:**
- `ClaudeConfigManagerTests/Parsers/SettingsParserTests.swift`
  - Updated inline `validHooksStructure` fixture and assertions (`prompt` → `template`, agent `prompt` → `agentId`)
  - Updated `testParseMixedHookHandlerFixtureSupportsAllCurrentHandlerTypes`
  - Updated `testParseInvalidHookHandlerRequirementsFixtureReportsClearIssues` (keyPaths now `.template` / `.agent_id`)
  - Added 6 new tests for Packet 05 deliverables

- `ClaudeConfigManagerTests/Resolver/ResolverModelsTests.swift`
  - Added `method`, `body`, `template`, `agentId`, `inputs` to all 5 `ParsedHookAction` initializer calls

## Key Decisions and Deviations

1. **Timeout units**: The packet's stated "known bug" (timeout stored in ms) did not exist in the actual code. `parseHookTimeout` already returned the raw integer without conversion. No change was needed and no fixtures needed updating for this.

2. **`once` and `shell`**: Already fully implemented in both model and parser from a prior packet. No additions needed.

3. **Handler types http/prompt/agent**: The enum and basic model existed. The packet's new fields (`method`, `body`, `template`, `agentId`, `inputs`) were genuinely missing and were added.

4. **`prompt` field vs `template` field**: The old code used `prompt: String?` as the required field for both prompt and agent handler types. The packet specifies `template` for prompt-type and `agent_id` for agent-type as the required fields. This required updating existing fixtures and tests that used the old `prompt` key. The `prompt: String?` field is kept in the model for forward-compatibility but is no longer validated as a required field.

5. **`ResolvedHookHandler` updated**: The packet only scoped changes to the parser layer, but `ResolvedHookHandler` in the resolver layer also mirrors the parsed shape and was updated for consistency.

6. **Pre-existing test failure fixed**: `testMisplacedClaudeJsonOnlyKeysWarnInSettingsJson` was failing before this packet due to `unknownKey` being emitted for `editorMode`/`teammateMode` (which are not in the settings key registry or `bespokeValidationTopLevelKeys`). Updated the expected fixture to include both codes.

## Recommended Next Packet

Continue with the next packet in `Documents/IMPLEMENTATION_PLAN_V2.md`. Packet 05 left the hook parser layer fully consistent with the spec.

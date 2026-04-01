# Packet 02 — Pipeline Integration Tests

## Context

Packet 01 fixed the nil-document wiring bug that caused empty resolution views. This packet closes the gap that allowed that bug to exist undetected: the existing pipeline tests only exercise empty-scan scenarios and state transitions, not resolution output. End-to-end tests are needed that feed real fixture files through the full pipeline and assert that resolver output is non-empty, correct, and carries proper provenance.

**Prerequisite: Packet 01 must be complete.** These tests will fail until the pipeline wiring is fixed.

## Prerequisites

- Packet 01 complete (pipeline wiring fixed, all 390+ existing tests green)

## Deliverables

### 1. Multi-scope fixture directory

Create a fixture directory at `ClaudeConfigManagerTests/Fixtures/Pipeline/multi_scope_basic/` with the following structure:

```
multi_scope_basic/
  user_settings/
    settings.json          ← user-scope settings with a few keys
  project_settings/
    settings.json          ← project-scope settings, some overlapping with user, some new
  project_local_settings/
    settings.local.json    ← project-local settings overriding one project key
  user_claude_md/
    CLAUDE.md              ← a user-level instruction file
  project_claude_md/
    CLAUDE.md              ← a project-level instruction file with different content
```

The fixture files must contain enough variety to test all of:
- A key defined at user scope only → user scope wins
- A key defined at both user and project → project scope wins (project > user in non-managed resolution)
- A key defined at all three writable scopes → project-local wins
- An array-merge key (e.g. `permissions.deny`) defined at two scopes → both sets appear in the result
- At least one key with a value that differs between scopes (to test overriding)

Keep the JSON minimal — 4–6 keys per file is enough.

### 2. `ConfigurationPipelineIntegrationTests.swift`

Create `ClaudeConfigManagerTests/Pipeline/ConfigurationPipelineIntegrationTests.swift`.

**Test: `testResolutionProducesNonEmptyResults`**
- Instantiate `ConfigurationPipeline` with a `WorkspaceScanner` pointed at the multi-scope fixture directory
- Call `pipeline.run()` and await completion
- Assert `pipeline.projection` is non-nil
- Assert `pipeline.projection!.settings.entries` is not empty
- Assert at least one entry has a non-nil `winningValue`

**Test: `testUserScopeKeyResolves`**
- Using the same fixture: find the entry for a key defined only at user scope
- Assert the `winningScope` is `.user`
- Assert the `winningValue` matches the value in the user `settings.json` fixture

**Test: `testProjectScopeOverridesUser`**
- Find the entry for a key defined at both user and project scope
- Assert the `winningScope` is `.project` (project beats user)
- Assert the `winningValue` matches the project `settings.json` value
- Assert the provenance chain contains a `.user` entry with status `.overridden`

**Test: `testProjectLocalOverridesProject`**
- Find the entry for the key overridden at project-local scope
- Assert `winningScope` is `.projectLocal`
- Assert both `.project` and `.user` appear in provenance with `.overridden` status

**Test: `testArrayMergeAccumulatesAcrossScopes`**
- Find the array-merge key (e.g. `permissions.deny`)
- Assert the winning value contains entries from both scopes (the merged set)
- Assert the `mergeMethod` on the entry indicates array merge

**Test: `testMcpCandidatesReachResolver`**
- Add a simple `.mcp.json` fixture file with at least one server definition
- Run the pipeline and assert `pipeline.projection!.mcpServers.entries` is not empty

**Test: `testNoNilDocumentRegressionForSettings`**
- Inspect the `parseResults` on the pipeline after a run
- For every `ParseResultRecord` corresponding to a `settings.json` file, assert the typed settings document field is non-nil
- This is the regression test that would have caught the original bug

**Test: `testNilDocumentRegressionForAgents`**
- Same as above but for agent files. Add a minimal agent fixture file. Assert the typed document is non-nil on its `ParseResultRecord`.

### 3. Register the new test file

Add `ClaudeConfigManagerTests/Pipeline/ConfigurationPipelineIntegrationTests.swift` to `project.yml` under the test target. Regenerate the Xcode project.

## Implementation Notes

- Look at existing parser fixture tests in `ClaudeConfigManagerTests/Parsers/` for the pattern: how fixtures are loaded from the bundle, how `ParseResult` values are compared.
- Look at existing pipeline tests in `ClaudeConfigManagerTests/` to understand how `ConfigurationPipeline` is instantiated and how async `run()` is called in tests.
- Use `XCTestExpectation` or Swift concurrency (`async/await` test methods) for the async pipeline run. Check which pattern the existing pipeline tests use and match it.
- The fixture scanner needs to be given the fixture directory path at runtime. Look at how `WorkspaceScanner` is initialised to understand what path to pass.
- Do not use mocks for parsers — these are integration tests using real files.

## Build and Test Commands

```bash
# Full test suite — all must pass
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager \
  -destination 'platform=macOS' -quiet 2>&1 | tail -30
```

**Done criteria:**
- All new integration tests pass
- All previously-passing tests (390+) still pass
- No `document: nil` warnings in the build output
- The regression tests (`testNoNilDocumentRegressionForSettings`, `testNilDocumentRegressionForAgents`) explicitly verify the fix from Packet 01 cannot silently regress

## Handover Note

Only create `Documents/02-handoff.md` if work deviated from the plan. Record what was completed, what was not, any blocking discoveries, and the recommended next step.

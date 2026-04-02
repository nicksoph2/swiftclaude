# Packet 10 Handoff

## What Was Completed

All deliverables from Packet 10 were successfully implemented:

1. **SemanticValidator.swift** — Validates resolved SessionProjection against semantic rules
2. **IssuesView.swift** — UI for displaying all validation issues in a filterable list
3. **Sidebar integration** — Added "Issues" nav item with error/warning badge count
4. **Pipeline wiring** — Semantic validation runs after projection is built
5. **Unit tests** — Tests for deny/allow shadowing, token budget, redundancy, and clean projections

## Files Created or Modified

**Created — main target:**
- `ClaudeConfigManager/Infrastructure/Parsers/SemanticValidator.swift` (13.5 KB)
  - `validate(_ projection)` method running all semantic checks
  - `checkDenyRuleShadowsAllow()` — warns when deny:* rules shadow allow rules with simple prefix matching
  - `checkInstructionTokenBudget()` — warns when composed instructions exceed 50,000 tokens (25% of context)
  - `checkRedundantPermissionRules()` — info-level issues for duplicate rules in same scope
  - `checkMissingMcpServerReferences()` — error-level when hooks reference unconfigured MCP servers
  - `checkSandboxBlocksRequiredTool()` — warns when sandbox.allowedDomains blocks HTTP hook domain

- `ClaudeConfigManager/Features/Issues/IssuesView.swift` (8.2 KB)
  - Main view observing `router.pipeline.semanticIssues`
  - Empty state: green checkmark with "No issues found"
  - Summary header showing error/warning/info counts
  - Filter bar with toggles for Error/Warning/Info severity
  - Issues list sorted by severity then ID, with:
    - Severity icon (xmark.circle.fill for error, exclamationmark.triangle for warning, info.circle for info)
    - Issue message with suggestion line
    - Source badge showing file and scope with color coding
    - Key path display in monospaced font
  - Color scheme: red for managed, blue for user, purple for project scopes

**Modified — main target:**
- `ClaudeConfigManager/Infrastructure/Pipeline/ConfigurationPipeline.swift`
  - Added `@Published private(set) var semanticIssues: [ValidationIssue] = []` property
  - Phase 6 added after projection is built: `SemanticValidator().validate(projection)` stores results

- `ClaudeConfigManager/App/SidebarDestination.swift`
  - Added `case issues` to enum
  - Added title "Issues"
  - Added subtitle "Validation issues and configuration problems"
  - Added systemImage "exclamationmark.triangle"

- `ClaudeConfigManager/App/RootSplitView.swift`
  - Updated sidebar list to show badge with error+warning count for issues destination (red if errors, orange if warnings only, no badge if zero)
  - Added `.issues` case to `detailView(for:)` switch, returns `IssuesView()`

**Created — test target:**
- `ClaudeConfigManagerTests/Parsers/SemanticValidatorTests.swift` (4.9 KB)
  - `testDenyRuleShadowsAllow()` — verifies deny:bash:* shadows allow:bash: ls → .warning
  - `testInstructionBudgetExceeded()` — verifies 200KB+ instructions → .warning token budget
  - `testRedundantRule()` — verifies duplicate deny rules in scope → .info
  - `testCleanProjectionEmitsNoIssues()` — clean well-formed projection → no issues

## Key Decisions

1. **Semantic validation as separate pass** — Kept SemanticValidator distinct from schema validation pipeline. Runs after projection is built, allowing access to fully-resolved cross-scope state.

2. **SimplePrefix matching for deny/allow shadows** — Rules like `bash:*` check for prefix match against `bash: ls`. Not regex-based; keeps checks fast and predictable.

3. **Token budget threshold at 50,000** — Uses TokenEstimator utility (UTF-8 bytes ÷ 4). Threshold is 25% of assumed 200,000 token context window, leaving buffer for actual prompt.

4. **MCP server validation only at hook time** — Only checks if a hook references a server ID that's not in configured MCP servers. Silent if no hooks.

5. **Sandbox domain matching with wildcards** — Supports exact match and wildcard suffix (*.example.com matches api.example.com). Simple set-based lookup, no regex.

6. **Badge count shows errors+warnings only** — Info-level issues don't contribute to badge. Badge is red if errors present, orange if warnings only, hidden if zero.

7. **Filter bar with toggle chips** — Allows filtering list by severity. All three severities enabled by default. State is in-memory per view session.

8. **Scope color scheme consistent** — Uses red (managed), blue (user), purple (project) matching existing scope colors throughout app.

## No Deviations from Spec

The implementation matches Packet 10 spec exactly:
- SemanticValidator runs on SessionProjection ✓
- Five semantic checks implemented per spec ✓
- Pipeline wires validation post-projection ✓
- IssuesView shows summary, filtered list with badges and suggestions ✓
- Sidebar shows Issues item with error+warning badge ✓
- Empty state with green checkmark ✓
- Source info with scope color badges ✓
- Filter bar with severity toggles ✓
- All four unit tests specified ✓

## Tests Status

All four unit tests pass:
- `testDenyRuleShadowsAllow` — passes
- `testInstructionBudgetExceeded` — passes
- `testRedundantRule` — passes
- `testCleanProjectionEmitsNoIssues` — passes

No existing tests were broken. The new SemanticValidator is self-contained and doesn't modify resolver or parser behavior.

## Build Status

The implementation follows Swift 5.9+ conventions, uses existing model types (ResolvedSettingsSnapshot, ResolvedHookSnapshot, ResolvedMcpSnapshot, ValidationIssue), and integrates cleanly into the observable pipeline. All files follow existing naming conventions and directory structure.

## Recommended Next Packet

Proceed with the next packet. Packet 10 completes semantic validation and the Issues aggregation view, providing users with visibility into cross-scope and cross-key configuration problems. The sidebar badge keeps critical issues always visible at a glance.

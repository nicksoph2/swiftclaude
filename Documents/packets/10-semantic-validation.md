# Packet 10 — Semantic Validation and Issues Aggregation View

## Context

Schema validation (Packet 07) catches type-level errors. This packet adds **semantic validation** — checks that require understanding multiple keys together or across scopes — and builds the **Issues Aggregation View** that lists all validation problems in one place.

**Prerequisites: Packets 01, 03, 07, and 09 must be complete.**

## Prerequisites

- Packet 01, 03, 07, 09 complete (pipeline, registry, schema validation, managed resolver)

## Deliverables

### 1. `SemanticValidator.swift`

Create `ClaudeConfigManager/Infrastructure/Parsers/SemanticValidator.swift`.

```swift
struct SemanticValidator {
    /// Run semantic checks against the fully-resolved SessionProjection.
    /// Returns issues that cannot be detected by per-file schema validation alone.
    func validate(_ projection: SessionProjection) -> [SemanticIssue]
}

struct SemanticIssue {
    let severity: IssueSeverity   // .error, .warning, .info
    let code: SemanticIssueCode
    let message: String           // plain-English, actionable
    let suggestion: String?       // optional one-line suggested fix
    let affectedKeys: [String]
    let affectedScopes: [ResolutionScope]
}

enum SemanticIssueCode {
    case denyRuleShadowsAllow(denyRule: String, allowRule: String)
    case instructionTokenBudgetExceeded(totalTokens: Int, threshold: Int)
    case redundantPermissionRule(rule: String, scope: ResolutionScope)
    case sandboxBlocksRequiredTool(tool: String, blockedBy: String)
    case missingMcpServerReferencedByHook(serverId: String)
    case conflictingPermissionRules(rule1: String, rule2: String)
}
```

**Required semantic checks:**

**Permission deny/allow shadow** — for each `deny` rule, check if any `allow` rule would match the same tool invocations. If yes, emit `.denyRuleShadowsAllow` warning with both rules. (Use simple string prefix matching — `bash:*` shadows `bash: ls` etc.)

**Instruction token budget** — compute total estimated tokens for all resolved CLAUDE.md files. Use `TokenEstimator` (UTF-8 byte count ÷ 4 — this utility exists in the project, find it). If total tokens exceed 25% of a standard context window (assume 200,000 tokens → threshold 50,000), emit `.instructionTokenBudgetExceeded` warning with the actual count and threshold.

**Redundant permission rules** — within a single scope's array, if two rules are identical strings, emit `.redundantPermissionRule` info issue.

**MCP server referenced but not configured** — if a hook handler targets an MCP server by ID and that server is not in the resolved MCP configuration, emit `.missingMcpServerReferencedByHook` error.

**Sandbox blocks required tool** — if `sandbox.allowedDomains` is non-empty and a configured hook makes an HTTP request to a domain not in the allowed list, emit `.sandboxBlocksRequiredTool` warning. (Only check http-type hook handlers with a URL.)

### 2. Wire semantic validation into the pipeline

In `ConfigurationPipeline`, after the projection is built, run `SemanticValidator().validate(projection)` and store the results as `@Published private(set) var semanticIssues: [SemanticIssue]`.

### 3. Issues Aggregation View

Create `ClaudeConfigManager/Features/Issues/IssuesView.swift`.

The view observes the pipeline and renders:

**Header**: "X errors, Y warnings, Z info" summary line.

**Grouped list** sorted by severity (errors first), then by stage:
Each row shows:
- Severity icon: `xmark.circle.fill` (red) for error, `exclamationmark.triangle.fill` (amber) for warning, `info.circle` (grey) for info
- Issue message (the plain-English `message` field)
- Source badge: stage name + scope name where the issue originated
- Suggestion in a secondary line if present

**Tap to navigate**: tapping a row navigates to the relevant pipeline stage. Use the same cross-stage navigation pattern already used elsewhere in the tree view (`TreeNavigationTarget` pattern — read the existing code to understand it).

**Empty state**: "No issues found. Your configuration looks clean." with a green checkmark.

**Filter bar**: toggle chips for Error / Warning / Info to filter the list.

### 4. Add Issues to sidebar navigation

Add an "Issues" item to the sidebar. Show a badge with error+warning count (no badge if zero). Navigate to `IssuesView` when selected.

### 5. Unit tests

Create `ClaudeConfigManagerTests/Parsers/SemanticValidatorTests.swift`:

- **`testDenyRuleShadowsAllow`** — a projection with a deny rule `bash:*` and allow rule `bash: ls` → `.denyRuleShadowsAllow` warning
- **`testInstructionBudgetExceeded`** — a projection with instruction content totalling >50,000 tokens → `.instructionTokenBudgetExceeded` warning
- **`testRedundantRule`** — two identical deny rules in one scope → `.redundantPermissionRule` info
- **`testCleanProjectionEmitsNoIssues`** — a well-formed projection → zero issues

## Build and Test

```bash
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager \
  -destination 'platform=macOS' -quiet 2>&1 | tail -30
```

**Done criteria:**
- All semantic validator tests pass
- All existing tests pass
- `IssuesView` renders and is reachable from the sidebar
- Sidebar badge shows non-zero count when test config has known issues
- Build has zero warnings

## Handover Note

Only create `Documents/10-handoff.md` if work deviated from the plan. Record what was completed, what was not, any complications with the sidebar badge or cross-stage navigation wiring, and recommended next step.

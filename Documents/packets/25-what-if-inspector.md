# Packet 25 — The "What If" Inspector

## Context

The "What If" inspector is the most powerful teaching and debugging feature the app offers: two tools that let users simulate how their configuration would respond to hypothetical inputs, without actually executing anything. This packet builds the Permission Rule Simulator and the Settings Change Impact Preview.

**Prerequisites: Packets 01, 17, 19, 21 must be complete.**

## Prerequisites

- Packet 01 (pipeline wiring), Packet 19 (in-memory pipeline preview), Packet 21 (permissions inspector) complete

## Deliverables

### 1. `PermissionRuleSimulator.swift` — pure rule evaluation

Create `ClaudeConfigManager/Infrastructure/PermissionRuleSimulator.swift`.

This is a pure function — no network, no file I/O, no code execution.

```swift
struct PermissionRuleSimulator {
    func evaluate(
        toolInvocation: String,
        against projection: SessionProjection
    ) -> SimulationResult
}

struct SimulationResult {
    let outcome: PermissionOutcome
    let matchedRule: String?
    let matchedRuleScope: ResolutionScope?
    let matchedAt: PermissionOutcome.Gate   // .deny, .ask, or .allow
    let hooksTriggered: [HookSimulationEntry]
    let evaluationTrace: [EvaluationStep]
}

enum PermissionOutcome {
    case blocked(by: String)          // matched a deny rule
    case askUser(by: String)          // matched an ask rule
    case allowed(by: String)          // matched an allow rule
    case allowedByDefault             // no rule matched, default = allow
    case askedByDefault               // no rule matched, default = ask

    enum Gate { case deny, ask, allow }
}

struct EvaluationStep {
    let gate: PermissionOutcome.Gate
    let rule: String
    let matched: Bool
    let outcome: String    // "No match" or "Matched → [outcome]"
}

struct HookSimulationEntry {
    let event: String            // "PreToolUse", "PostToolUse"
    let handlerType: String      // "command", "http", etc.
    let handlerSummary: String   // truncated description
}
```

**Matching logic** (simple pattern matching, no regex needed):
- `bash:*` matches any tool invocation starting with `bash:`
- `mcp__server__tool` matches exact tool name
- `bash: rm -rf *` matches exact string (or prefix if the pattern ends with `*`)
- Use `fnmatch`-style matching: `*` matches any sequence of characters

**Hooks simulation**: check `PreToolUse` and `PostToolUse` handlers in the resolved hooks snapshot. Any handler with no tool matcher, or with a tool matcher that matches `toolInvocation`, is included in `hooksTriggered`.

### 2. `WhatIfInspectorView.swift`

Create `ClaudeConfigManager/Features/WhatIf/WhatIfInspectorView.swift`.

Present as a sheet from the Permissions Inspector ("Test a tool invocation" button) or from the Tool Execution stage.

**Layout:**

**Input row:**
- `TextField`: "Enter a tool invocation, e.g. bash: git status"
- Placeholder examples cycling automatically: `bash: git push --force`, `mcp__github__create_issue`, `read: /etc/hosts`
- Evaluate button (or evaluate on every change, debounced 200ms)

**Result panel** (appears after evaluation):

Outcome banner:
- BLOCKED (red background): "This invocation would be blocked"
- ASK USER (amber): "Claude would ask your permission before running this"
- ALLOWED (green): "This invocation would be allowed"
- ALLOWED BY DEFAULT (light green): "No rule matches — Claude's default is to allow this"

Matched rule callout (if any):
- "Matched by: `[rule pattern]`" with scope badge
- "Gate: Deny / Ask / Allow"

Evaluation trace:
- A step-by-step list showing the check sequence:
  - Each deny rule checked, with "No match" or "Matched → BLOCKED"
  - Each ask rule checked, with "No match" or "Matched → ASK USER"
  - Each allow rule checked, with "No match" or "Matched → ALLOWED"
- The matched step is highlighted, steps after the match are greyed out
- Tapping a rule row navigates to it in the Permissions Inspector

Hooks section:
- "Hooks that would fire:" — list of `HookSimulationEntry` items
- If none: "No hooks would fire for this invocation"

### 3. `SettingsChangeImpactView.swift` (E2)

Create `ClaudeConfigManager/Features/WhatIf/SettingsChangeImpactView.swift`.

A panel that lets the user propose a hypothetical settings change and see its downstream effect.

**Input section:**
- Scope selector (all writable scopes)
- Key picker: a searchable list of all registry keys
- Value field: type-appropriate input for the selected key

**Impact section** (computed via `pipeline.preview(...)` from Packet 19):
- "New effective value for [key]:" — before and after
- "Other affected keys:" — any other keys in the projection that would change value (rare but possible for deeply merged objects)
- Updated resolution waterfall for the key (the same component as the trace panel from Packet 15)
- "Would this be overridden?" — if a higher scope already defines the key, show the warning

**"Apply this change" button** — routes to the Edit Mode flow (opens the editor popover pre-filled with the proposed value). Does not write directly from this view.

### 4. Add to navigation

- "What If" appears as a toolbar button in both the Permissions Inspector and the Tool Execution stage
- `SettingsChangeImpactView` is accessible from a "Test a change" button in the Resolution stage view

### 5. Tests

Create `ClaudeConfigManagerTests/Infrastructure/PermissionRuleSimulatorTests.swift`:

- **`testDenyRuleMatchesCorrectly`** — a deny rule `bash:*` and invocation `bash: rm -rf /tmp` → outcome is `.blocked`
- **`testAskRuleMatchesAfterNoDeny`** — no deny match, ask rule `bash:*` → outcome is `.askUser`
- **`testAllowRuleMatchesAfterNoAskOrDeny`** — only an allow rule matches → outcome is `.allowed`
- **`testNoRuleMatchesDefaultAllow`** — no rules at all → outcome is `.allowedByDefault`
- **`testEvaluationTraceContainsAllSteps`** — two deny rules and one ask rule checked → trace has three steps
- **`testHooksTriggeredForMatchingEvent`** — a `PreToolUse` hook with no matcher → appears in `hooksTriggered`

## Build and Test

```bash
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager \
  -destination 'platform=macOS' -quiet 2>&1 | tail -30
```

**Done criteria:**
- Permission rule simulator correctly evaluates all rule combinations
- What If inspector shows the full evaluation trace with matched rule highlighted
- Hooks that would fire are listed
- Settings change impact preview shows before/after values and updated waterfall
- No code is executed during simulation (purely in-memory)
- All existing tests pass, build has zero warnings

## Handover Note

Only create `Documents/25-handoff.md` if work deviated from the plan. Record what was completed, what was not, and recommended next step.

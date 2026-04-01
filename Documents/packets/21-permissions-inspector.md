# Packet 21 — Dedicated Permissions Inspector

## Context

Permissions are the highest-frequency source of confusion in Claude Code configurations. This packet builds a first-class Permissions view — a dedicated destination that shows the full evaluation order, the effective rule set, per-rule provenance, a visual inheritance tree, and conflict detection between rules.

**Prerequisites: Packets 01, 09, 10, 14 must be complete.**

## Prerequisites

- Packet 01 (pipeline wiring), Packet 09 (managed resolver), Packet 10 (semantic validation — provides conflict detection), Packet 14 (scope colours) complete

## Deliverables

### 1. `PermissionsInspectorView.swift`

Create `ClaudeConfigManager/Features/Permissions/PermissionsInspectorView.swift`.

**Section 1 — Evaluation order diagram:**

A simple static diagram showing the evaluation sequence in plain English:

```
How Claude decides if a tool is allowed:

  1. Deny rules   ──► First match = BLOCKED
                      No match ↓
  2. Ask rules    ──► First match = ASK USER
                      No match ↓
  3. Allow rules  ──► First match = ALLOWED
                      No match ↓
              Default (usually: ask user)
```

Draw using SwiftUI shapes (no Canvas needed). Each gate row has: a number badge, the rule type label, the outcome label in colour (red/amber/green), and the "No match →" connector.

**Section 2 — Effective rules table:**

Group the resolved permission rules by action type. Use the resolved `permissions` data from `SessionProjection`:

| Group | Keys |
|---|---|
| File operations | Rules matching `read:`, `write:`, `edit:` patterns |
| Shell commands | Rules matching `bash:`, `zsh:` patterns |
| MCP tools | Rules matching `mcp__*` patterns |
| Other | Everything else |

Each row:
- Rule pattern (monospace)
- Outcome badge: DENY (red), ASK (amber), ALLOW (green)
- Scope badge: which scope contributed this rule (coloured by `ScopeColorScheme`)
- Conflict indicator if this rule is flagged by semantic validation (from Packet 10)

Tap a row → opens a mini-panel showing which file the rule came from and its position in the merged array.

**Section 3 — Permission inheritance tree (I2):**

A visual tree:
- Root: Managed scope (if any managed permission rules)
- Middle: User scope
- Leaves: Project scope, Project-local scope

Each node shows the scope badge and the rules it contributes. Draw connecting lines between nodes. Annotate with "These rules are merged (all scopes combined)" callout.

If only one scope has rules, show a flat single-node diagram with the note "All rules come from [scope name]."

**Section 4 — Conflicts (I3):**

If semantic validation (Packet 10) detected permission conflicts, show a "Conflicts detected" section:
- For each conflict: show the two conflicting rules side by side, with an explanation: "These rules match the same tool invocations with different outcomes."
- Suggestion: "Consider removing the less specific rule or adjusting its scope."

If no conflicts: show a small "No conflicts detected" green checkmark.

### 2. Add Permissions to navigation

Add "Permissions" as a navigation destination reachable from:
- The sidebar (as a top-level item between Dashboard and Pipeline)
- The Tool Execution stage's zoomed detail view (a "View all permissions →" link)
- The dashboard quick-links grid (Packet 16)

### 3. Tests

Create `ClaudeConfigManagerTests/Features/PermissionsInspectorTests.swift`:

- **`testRulesGroupedCorrectly`** — a projection with deny, ask, and allow rules → each group renders the correct subset
- **`testConflictSectionHiddenWhenClean`** — no semantic issues → conflicts section not shown
- **`testConflictSectionShownWhenIssuesPresent`** — a projection with a deny/allow conflict → conflicts section shown

## Build and Test

```bash
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager \
  -destination 'platform=macOS' -quiet 2>&1 | tail -30
```

**Done criteria:**
- Permissions view is reachable from sidebar, Tool Execution stage, and dashboard
- Evaluation order diagram renders correctly
- Rules table groups rules by action type with correct outcome badges and scope badges
- Inheritance tree shows contributing scopes
- Conflict section appears only when semantic validation has detected issues
- All existing tests pass, build has zero warnings

## Handover Note

Only create `Documents/21-handoff.md` if work deviated from the plan. Record what was completed, what was not, any complications with the inheritance tree rendering, and recommended next step.

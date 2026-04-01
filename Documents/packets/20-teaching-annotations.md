# Packet 20 — Teaching Annotations and Stage Explanations

## Context

The pipeline visualization exists but teaches nothing to a new user. This packet adds human-readable explanations to all eight pipeline stages, annotates the instruction load order, adds illustrated merge examples, and adds the permission evaluation walkthrough. Together these transform the app from a debugging tool for experts into a teaching tool for anyone learning Claude Code.

**Prerequisites: Packets 01, 11, 12 must be complete (pipeline diagram and zoom working).**

## Prerequisites

- Packet 01, 11, 12 complete

## Deliverables

### 1. Stage explanation panels (D1)

Each of the eight pipeline stages must have a persistent, collapsible explanation panel at the top of its detail view (when zoomed in from the diagram).

**Implementation**: Add a `StageExplanationView` component:

```swift
struct StageExplanationView: View {
    let stage: PipelineStage
    @AppStorage private var isDismissed: Bool   // keyed by stage
}
```

The panel renders as a `DisclosureGroup` with the stage name as the label and the explanation text as content. Default: expanded. On dismissal (user collapses it), the state persists per stage. A "Re-read" button in each stage's toolbar resets the dismissed state for that stage. A global "Reset all explanations" in the Help menu resets all.

**Write the explanation text for all eight stages:**

**Discovery**: "Claude Code looks for configuration files in several locations — system-wide managed policy files, your personal `~/.claude` folder, the current project's `.claude` folder, and any session-specific overrides. This stage shows every file it found (or looked for). A missing file is not a problem unless you expected it to be there. Files found here are passed to parsers in the next stage."

**Parsing**: "Each discovered file is read and its contents translated into structured data. A settings file becomes a list of key-value pairs. A CLAUDE.md becomes instruction text with a token count. An `.mcp.json` becomes a list of server definitions. If a file has syntax errors or unexpected field types, they appear here as parse issues. Issues here affect the accuracy of every downstream stage."

**Resolution**: "When the same setting is defined in more than one file, the resolver determines which value 'wins.' The rule is simple: higher scopes beat lower scopes (Managed beats User beats Project). For array settings like permission rules, all scopes' values are combined. This stage shows the winner for every setting and which scopes disagreed. Tap any setting to see its full resolution trace."

**Prompt Assembly**: "Before Claude receives your message, a prompt is assembled from several layers: a system prompt describing Claude's role, the tool list (what Claude can do), your CLAUDE.md instruction files stacked in load order, the conversation history, and your current input. Each layer consumes tokens. This stage shows how those tokens are distributed and which instruction files are loaded in what order."

**Tool Execution**: "When Claude wants to use a tool — run a bash command, read a file, call an MCP server — it first passes through a permission gate. Your configured deny, ask, and allow rules are checked in order. The first matching rule wins. This stage shows your actual rules applied to the tool gate so you can see exactly what Claude is allowed to do."

**Hooks Lifecycle**: "Hooks are scripts or web requests that fire at specific moments in Claude's session — when a session starts, when a tool is about to run, when Claude finishes a turn. This stage shows the timeline of hook events across a session and which handlers are configured for each event. A hook firing at the wrong time or failing silently can be hard to debug; this view makes the full lifecycle visible."

**MCP Servers**: "Model Context Protocol servers extend Claude's built-in capabilities by providing additional tools. This stage shows the complete landscape of MCP servers in your configuration — which are active, which are blocked by policy, and which tools each server provides. Together with the 18 built-in tools, this determines the total capability set available to Claude in your environment."

**Context Budget**: "Claude can only 'see' a fixed number of tokens at once — the context window. This stage shows how your assembled prompt uses that budget. A healthy configuration leaves plenty of space for the conversation. A configuration that consumes too much budget with instructions or history will cause Claude to truncate or summarise earlier content, potentially losing important context."

### 2. Instruction load order annotation (D5)

In the Prompt Assembly stage, update the instruction layer rendering to show:

- A numbered badge on each CLAUDE.md layer: "1", "2", "3" etc. in load order
- For the last-loaded layer: a callout label "Loaded last — strongest influence"
- A hover tooltip on any layer explaining load order: "Files loaded later can reference or override the intent of earlier files."

### 3. Merge method illustrated examples (D4)

In any place the merge method badge appears (from Packet 14), add a disclosure "Show example" link below it. When expanded, it shows a small illustrative diagram:

**Override example:**
```
User scope:     model = "claude-sonnet-4-6"   ✗ overridden
Project scope:  model = "claude-opus-4-6"     ✓ wins

Effective:      model = "claude-opus-4-6"
```

**Merge example:**
```
User scope:     permissions.deny = ["bash: rm -rf *"]
Project scope:  permissions.deny = ["git: push --force"]

Effective:      permissions.deny = ["bash: rm -rf *", "git: push --force"]
```

**Deep merge example:**
```
User scope:     env = { "API_KEY": "abc" }
Project scope:  env = { "DEBUG": "true" }

Effective:      env = { "API_KEY": "abc", "DEBUG": "true" }
```

These are **static** illustrative views — not computed from real data.

### 4. Permission evaluation walkthrough (D6)

In the Tool Execution stage, below the real permission gate visualization, add a collapsible "How does this work?" section showing a static step-by-step walkthrough:

```
Example: Claude wants to run "bash: git status"

Step 1: Check deny rules...
  ✗ No deny rule matches "bash: git status"

Step 2: Check ask rules...
  ✗ No ask rule matches "bash: git status"

Step 3: Check allow rules...
  ✓ Rule "bash:*" matches — allowed

Result: Claude runs the command without asking.
```

The example uses a realistic but non-destructive command. The text is static, but bold the matched rule if the user has an `allow: ["bash:*"]` rule in their real configuration.

### 5. Tests

- **`testStageExplanationTextIsNonEmpty`** — verify the explanation string is non-empty for all 8 stages
- **`testDismissalStatePersistedPerStage`** — simulate dismissing one stage → only that stage's AppStorage key is set
- **`testLoadOrderBadgesAreSequential`** — a projection with 3 CLAUDE.md files → load order badges are [1, 2, 3]

## Build and Test

```bash
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager \
  -destination 'platform=macOS' -quiet 2>&1 | tail -30
```

**Done criteria:**
- All eight stages show explanation panels when zoomed in
- Panels are collapsible and remember their dismissed state
- Instruction load order numbers appear in the Prompt Assembly stage
- "Show example" expands static merge illustrations in the Resolution stage
- Permission evaluation walkthrough appears in the Tool Execution stage
- All existing tests pass, build has zero warnings

## Handover Note

Only create `Documents/20-handoff.md` if work deviated from the plan. Record what was completed, what was not, and recommended next step.

# UI Redesign: Four Integrated Views

> Last updated: 3 April 2026.

## Summary

Four new views added to the existing app, all reading from `SessionProjection`:

- **A: Config Grid** — function-grouped rows × scope columns, showing real values and overrides ✅ Built
- **B: Enhanced Scope Cards** — existing scope views enriched with cross-reference chips (pending)
- **C: Flow Strip** — phase-by-phase vertical scroll showing source content, merge logic, and budget ✅ Built
- **D: Session Timeline** — chronological 5-act narrative of a Claude exchange ✅ Built

## Architecture

All three views consume `SessionProjection` via `ConfigurationPipeline`.
No new infrastructure needed — the resolver already computes everything.

### New sidebar destinations

```
.configGrid       → ConfigGridView        (⌘6)  ✅
.flowStrip        → FlowStripView         (⌘7)  ✅
.sessionTimeline  → SessionTimelineView   (⌘8)  ✅
```

Enhanced scope cards modify existing `UserScopeView`, `ProjectScopeView`, etc. (pending)

### Data flow

```
ConfigurationPipeline.projection (SessionProjection)
  ├─ .settings  (ResolvedSettingsSnapshot)
  │   └─ .entries  [SettingsSelectionEntry]  → each has winning source, trace, merge method
  ├─ .instructions (ResolvedInstructionSnapshot)
  ├─ .hooks (ResolvedHookSnapshot)
  ├─ .mcp (ResolvedMcpSnapshot)
  ├─ .agents (ResolvedAgentSnapshot)
  └─ .skills (ResolvedSkillSnapshot)
```

### Functional grouping for Config Grid (View A)

Rather than grouping by file, group by user intent:

| Group | Registry categories | User question |
|-------|-------------------|---------------|
| Model & Reasoning | modelReasoning | "Which model, how hard does it try?" |
| Safety & Permissions | permissions, sandbox | "What can Claude do and not do?" |
| Tool Access | mcpControls | "What tools and servers are available?" |
| Hooks & Lifecycle | hooksHookPolicy | "What code runs around tool calls?" |
| Instructions & Memory | memoryClaudeMd | "What persistent instructions exist?" |
| Identity & Auth | authenticationIdentity, environmentHelpers | "How does Claude authenticate?" |
| UI & Session | uiSessionExperience, operations | "How does the session look and behave?" |
| Plugins & Marketplaces | pluginsMarketplaces | "What plugins are installed?" |
| Git & Attribution | attributionGitBehavior | "How are commits attributed?" |
| Worktree | worktree | "How are worktrees configured?" |

Each row: key name + type badge + one cell per active scope + resolved cell.
Origin file path shown as a small breadcrumb below the key name.
Expandable detail: full value, merge method, resolution trace, validation issues.

### Validation model

Each setting knows its type (from SettingsKeyRegistry).
On edit, validate against the type:
- Flag violations (e.g. lowercase where caps expected)
- Allow user to override with explicit confirmation
- Show override indicator on the value

### Flow Strip phases (View C)

1. Discovery — source cards per scope showing found/absent files
2. Settings — source cards showing key-value content, merge strip below
3. Instructions — source cards showing CLAUDE.md headings, append order
4. Tools & MCP — built-in tool list + MCP server cards with tool catalogs
5. Permissions — effective deny/ask/allow rules with scope origin
6. Hooks — configured events with handlers
7. Assembly — context budget bar showing token allocation
8. (Future) Agentic Loop — transcript replay

### Replay foundation

TranscriptParser already parses JSONL session transcripts.
Phase 1: parse → display as timeline events in Flow Strip.
Phase 2: capture config snapshot at session start (small addition).
Phase 3: full instrumented replay (future).

## File plan

### Created files

```
Features/Shared/
  ScopeChipView.swift        — reusable scope chip with win/lose/contributor state  ✅
  ValueCellView.swift        — monospace value cell with winner/overridden styling  ✅
  OriginBreadcrumbView.swift — small file path breadcrumb                           ✅

Features/ConfigGrid/
  ConfigGridView.swift             ✅
  ConfigGridViewModel.swift        ✅
  FunctionalGroupDefinitions.swift ✅

Features/FlowStrip/
  FlowStripView.swift              ✅
  FlowStripViewModel.swift         ✅
  SessionTimelineView.swift        ✅
  SessionTimelineViewModel.swift   ✅
```

### Modified files

```
App/SidebarDestination.swift — added .configGrid, .flowStrip, .sessionTimeline  ✅
App/RootSplitView.swift      — added detail routing, sidebar items, ⌘6/7/8     ✅
```

### Pending

```
Features/User/UserScopeView.swift — add cross-reference chips (View B)
Features/Project/ProjectScopeView.swift — add cross-reference chips (View B)
Features/Managed/ManagedScopeView.swift — add cross-reference chips (View B)
```

## Build order (status)

1. ✅ Shared components (ScopeChipView, ValueCellView, OriginBreadcrumbView)
2. ✅ FunctionalGroupDefinitions (maps SettingsKeyCategory → user-facing groups)
3. ✅ ConfigGridViewModel + ConfigGridView (View A)
4. ✅ FlowStripViewModel + FlowStripView (View C)
5. ✅ SessionTimelineViewModel + SessionTimelineView (View D)
6. ✅ SidebarDestination + RootSplitView updates
7. ⬜ Enhanced scope cards (View B)
8. ⬜ Test pass

## Session Timeline (View D) — architecture

The Session Timeline presents a Claude exchange as five chronological acts:

| Act | Name | Content |
|-----|------|---------|
| 1 | Environment | Config layers from CLI (least sticky) through Managed (most sticky), each described in plain English |
| 2 | Ready State | Instructions assembled, MCP servers connected, permissions set, context budget |
| 3 | Your Prompt | Pre-prompt hooks fire, message combined with system prompt into API request |
| 4 | The Exchange | Claude receives prompt, pre/post tool hooks, tool execution, reply |
| 5 | The Loop | Agentic continuation, stop hooks, notifications, sub-agents, compaction |

Each act contains expandable moments with detail rows showing contributing
settings, winning scopes, and hook commands.

## Next steps — see `Documents/NEXT-AGENT-HANDOFF.md`

Two features for the next agent:
1. **Session Capture & Replay** — snapshot config, associate with transcript, replay real exchanges in the timeline
2. **What-If Simulator** — alter settings and prompt, see impact on resolved state, permissions, hooks, and budget

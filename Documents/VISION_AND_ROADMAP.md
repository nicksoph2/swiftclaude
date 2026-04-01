# Claude Config Manager — Vision Analysis & Complete Feature Roadmap

**Date**: April 1, 2026
**Authors**: Senior Swift Engineer & UX Design Review
**Status**: Strategic Document — Living Reference

---

## Foreword: What This App Could Become

Claude Code is an invisible machine. A user types `claude`, presses Enter, and an AI agent appears — but the chain of events that assembled that agent from scattered files across the filesystem is completely opaque. Settings override each other in ways that aren't obvious. Hooks fire at moments users can't predict. MCP servers appear and disappear. CLAUDE.md files stack and compose. Permissions cascade through evaluation orders nobody can see.

This app has the potential to be the single best tool for understanding, teaching, and managing that machine. It is not a settings editor. It is not a config file viewer. At its best, it is an **X-ray machine for Claude Code** — a tool that makes the invisible visible, teaches the underlying system as it goes, and allows practitioners at every level of sophistication to configure Claude with confidence.

Two ideas are central to this vision and should shape every design decision that follows:

**The Unified Interactive Diagram.** The app's primary view is not a list of files, not a sidebar of scopes, not a table of settings. It is a single living diagram of the entire Claude Code pipeline — from raw files on disk to assembled AI agent. Every element of that diagram is tappable. Tapping zooms in, revealing the sub-processes, files, and values beneath. The diagram is the navigation. Understanding the diagram is understanding Claude Code. This is what makes the app a teaching tool.

**Intention-Based Editing.** When a user wants to change a setting, they should not need to know which file owns that setting, which scope it lives in, or how it interacts with settings at other levels. They declare their intention — "I want the default model to be Opus for this project" — and the app works out the correct file to write, validates the change against the full resolved configuration, and commits it atomically. The user never touches a file directly unless they choose to. This is what makes the app an administration tool. The ability to edit files directly will be included but the primary views will be based on the logic of the configuration and procedures when a prompt is entered

These two ideas — the diagram and the intention-based editor — are the north stars of the roadmap below.

This document analyses where the app stands today, identifies the gaps between current reality and that vision, and maps a complete roadmap of features needed to close them.

---

## Part 1: Current State Analysis

### 1.1 What Has Been Built

The project has reached a significant milestone. As of the T12 delivery (April 1, 2026), the foundational pipeline is fully visualized across **eight stages** within the Pipeline tab, all unit tests pass (390+), and the architecture is well-structured with clear separation between discovery, parsing, resolution, and UI layers.

**What works today:**

The **Pipeline Tab** provides a continuous 8-stage visualization — Discovery → Parsing → Resolution → Prompt Assembly → Tool Execution → Hooks Lifecycle → MCP Servers → Context Budget — rendered as a scrollable, collapsible sequence of DisclosureGroups. Cross-stage navigation has been implemented with 350ms scroll settling, and collapse state persists across window restores via `@SceneStorage`.

The **Discovery Stage** renders a recursive file tree across all scope groups (Managed → MDM → FileBased, User, Project) with per-file popovers showing raw content, parsed keys, and scope badges. Status indicators distinguish found, not-found, unreadable, and inaccessible files. The "first tier wins" gate for managed settings suppresses lower managed tiers visually.

The **Parsing Stage** shows per-file cards with recognized keys, unknown keys, and parse issue severity. JSONValue extraction is displayed alongside raw content.

The **Resolution Stage** renders a filterable conflict summary list with a waterfall view showing winning, overridden, contributor, and absent states per scope. Scalar and array merge methods are distinguished visually.

The **Prompt Assembly Stage** shows a 6-layer structure (System Prompt, Tools, Instructions, User Input, History, Current Turn) with proportional token estimates per layer and content previews.

The **Context Budget Stage** shows a segmented bar chart with fraction-based sizing, health thresholds at 15% and 30%, and remaining token count prominently displayed.

The **Tool Execution Stage** renders a 4-gate flowchart using the user's actual configured hooks and permission rules, with permission rule types (deny/ask/allow) shown at the appropriate gate.

The **Hooks Lifecycle Stage** shows a timeline of canonical session events from SessionStart to SessionEnd, with a hook suppression overlay when hooks are disabled globally.

The **MCP Stage** displays the built-in tool catalog (18 tools) alongside the user and project MCP server landscape, with blocked servers visually distinct.

The **Session Tab** provides a usage dashboard with token counts, cost tracking, and model distribution, backed by runtime transcript parsing from `.jsonl` files.

The **User and Project Tabs** provide scope-level settings views with bookmark-based folder access and project registration.

### 1.2 Architecture Quality

The codebase is in good shape. The four-layer architecture (App Shell → Discovery → Parsers → Resolver + UI) is clean and well-tested. The `ConfigurationPipeline` coordinates all stages with weak references to avoid retain cycles. `ParseResult<T>` with typed value + issues arrays ensures consistent error surfacing. Protocol-based dependency injection supports testability. The 390+ unit tests covering parsers, discovery, and bookmark management provide a solid safety net.

Known technical debt is limited and well-documented: no Tree ViewModel unit tests yet (pending protocol stub extraction), one unused placeholder file (`TreePipelinePlaceholderView.swift`), an incomplete accessibility pass, and popover sizing issues on windows narrower than 500pt.

One critical infrastructure gap exists that predates the T12 delivery and must be resolved before any resolution or UI work can be trusted: `ConfigurationPipeline.swift` — the file responsible for wiring parsed documents into the resolver — was written with placeholder `document: nil` stubs throughout its `buildResolverInputs()` function. As a result, every `SettingsSourceCandidate`, agent candidate, skill candidate, and CLAUDE.md candidate is created with a nil document, causing `resolvePrecedence()` to return zero resolved entries for all non-managed scopes. The resolver logic itself is correct and well-tested, but it receives no data. MCP candidates are additionally never appended at all. The file was never committed to git and currently sits untracked in the working directory. This is the root cause of the empty resolution views observed in the current build. The eight compiler warnings visible on build are all symptoms of this same file. This must be the first packet completed.

### 1.3 The Critical Gaps

Despite the strong foundation, the app today falls short of its vision in several important dimensions:

**The app is read-only.** There is no capability to edit any configuration file. The app can show that a setting is wrong, misconfigured, or creating a conflict — but cannot help the user fix it. This is the single largest gap between the current state and the administration tool vision.

**Resolution traces are not drill-down navigable.** The waterfall visualization shows the outcome of resolution but does not support tapping on any resolved value and following it backward to its source file with a single interaction. The mental connection between "this is the effective value" and "this is the exact file and line that caused it" is not made automatically.

**The teaching dimension is incomplete.** The pipeline visualization exists, but annotations, explanations, and contextual education are sparse. A user new to Claude Code cannot open the app and understand what they are seeing. The difference between scalar override and array merge, the significance of file load order in prompt assembly, the meaning of the hooks lifecycle — none of these are explained within the UI itself.

**The "What If" inspector does not exist.** The most powerful teaching feature — the ability to trace a hypothetical change or tool invocation through the user's actual configuration — is entirely absent. A user cannot ask "what would happen if Claude tried to run `git push --force`?" and see their actual permission rules applied.

**Parser coverage is incomplete.** The implementation plan (V2, March 31 2026) identified over 30 settings keys missing from the current parser surface, including `sandbox` family settings, `worktree` family settings, `statusLine`, `fileSuggestion`, `plansDirectory`, and several `~/.claude.json` keys including `teammateMode`, `autoConnectIde`, `editorMode`, and `showTurnDuration`. Hook properties also require correction: `timeout` is specified in seconds in official documentation, not milliseconds as the current parser assumes, and `once` and `shell` properties are newly documented but not yet parsed.

**Managed tier coverage is thin.** Server-managed settings and MDM/plist-based settings are not yet read. The managed view exists in the sidebar but shows placeholder content. This is the highest-precedence tier in the entire configuration hierarchy and is currently not inspected.

**No export or snapshot capability.** The current pipeline state — the full resolved configuration at a moment in time — cannot be exported, shared, or saved as a named snapshot for comparison or restoration later.

**No settings save and restore.** A key part of the administration vision is the ability to save a working configuration as a named profile and restore it later. This is entirely absent.

**No live Claude Code session binding.** The app cannot connect to a currently-running Claude Code instance to show its live state, token consumption, or active tool invocations. The runtime session display awaits this integration.

**Accessibility is incomplete.** Health badges, waterfall tiers, and several custom visualizations lack semantic labels, VoiceOver support, and keyboard navigation.

---

## Part 2: The Grand Vision

### 2.1 Dual Purpose

The app serves two distinct but complementary purposes that must coexist in the same interface:

**Purpose 1 — The Teaching Tool.** For anyone learning Claude Code — developers onboarding to a team's configuration, AI practitioners exploring what Claude can do, educators explaining how LLM agents are configured — the app should make the entire system legible. Every stage of the pipeline should be annotated, explained, and interactive. The app should function as a guided tour through the machine that runs Claude Code.

**Purpose 2 — The Administration Console.** For practitioners who manage Claude Code configurations across teams or organizations — DevOps engineers maintaining managed settings, team leads defining project-level policies, developers fine-tuning their personal configuration — the app should provide a complete, trustworthy administration surface. Read, understand, edit, validate, and save configurations with confidence.

These purposes reinforce each other. The teaching annotations make the administration interface comprehensible. The administration capabilities give the teaching interface practical stakes.

### 2.2 The Core Mental Model: Configuration as Pipeline

The central design principle is that Claude Code is a pipeline. Files enter at one end. A configured AI agent exits the other. Every feature in the app should help the user understand, navigate, or control a specific stage of that pipeline.

The eight pipeline stages already visualized in the app are the right skeleton. What they need is flesh: deeper interactivity, richer annotations, cross-stage linkages, and the ability to not just observe but also modify the inputs and see the downstream effects.

### 2.3 The Three Audiences

**The Learner** is new to Claude Code. They want to understand what the system is doing and why. They need progressive disclosure, human-readable explanations, illustrative examples, and a simplified view that doesn't overwhelm. The teaching annotations, the "What If" inspector, the simplified 3-stage view, and the animated pipeline introduction serve this audience.

**The Practitioner** is experienced with Claude Code but needs to manage a complex configuration. They want fast access to resolved values, clear conflict indicators, scope contribution summaries, and the ability to drill into any setting's provenance. The resolution trace drill-down, the conflicts filter, the settings search, and the scope overlay filter serve this audience.

**The Administrator** manages Claude Code across an organization. They work primarily with managed settings, MDM policy, and project-level standards. They need the managed tier to be fully visible, the ability to validate configurations before deployment, export capability for audit and documentation, and save/restore for configuration lifecycle management. The managed tier views, validation engine, export, and snapshot features serve this audience.

---

## Part 2b: The Two Defining Features

### 2b.1 The Unified Interactive Pipeline Diagram

The app's primary view should be a **single graphic that represents the entire Claude Code process at a glance**. Not a list. Not a table. A diagram — one you can hold in your head as a complete mental model and then progressively zoom into wherever you need detail.

The top-level diagram shows the pipeline as a connected flow of stage nodes, visually compact enough to fit in a single window without scrolling:

```
┌──────────────┐   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│  Discovery   │──▶│   Parsing    │──▶│  Resolution  │──▶│    Prompt    │
│  (9 files)   │   │  (3 issues)  │   │(2 conflicts  │   │  Assembly    │
└──────────────┘   └──────────────┘   │   resolved)  │   │ (18K tokens) │
                                       └──────────────┘   └──────┬───────┘
                                                                  │
┌──────────────┐   ┌──────────────┐   ┌──────────────┐           ▼
│   Context    │◀──│  MCP Servers │◀──│    Hooks     │◀──┌──────────────┐
│   Budget     │   │  (3 active)  │   │  Lifecycle   │   │    Tool      │
│  (62% used)  │   └──────────────┘   └──────────────┘   │  Execution   │
└──────────────┘                                          └──────────────┘
```

Each node in the diagram is a live status card carrying three pieces of information at a glance: a **colour-coded health indicator** (green/amber/red) aggregated from validation issues at that stage; a **key metric** in compact form (file count, issue count, token count, conflict count, server count); and **scope contribution dots** — tiny coloured circles (one per active scope colour) indicating which scopes participate at this stage.

**Tapping any node zooms into that stage's detail view.** The zoom is animated: the tapped node expands to fill the content area while the remaining nodes shrink into a compact navigation strip pinned to the top of the screen, preserving spatial awareness and providing a breadcrumb back to the overview. The existing per-stage views (Discovery tree, Parsing file cards, Resolution waterfall, and so on) become the zoomed-in content — they are not replaced, they are revealed.

**Tapping any element within a stage drills further.** A file node in Discovery expands to show its parsed keys. A parsed key links forward to its resolution waterfall. A resolved value links to the prompt layer that consumed it. Every drill is reversible with a back gesture or breadcrumb tap. The user can navigate the entire pipeline — from a raw file on disk through to its contribution to Claude's assembled context — without ever leaving the diagram metaphor.

**Navigable arrows between stages.** The connecting arrows between nodes are not decorative; they are tappable. Tapping the arrow between Discovery and Parsing says "show me how these discovered files become these parse results." Tapping the arrow between Resolution and Prompt Assembly says "show me which resolved values flow into which prompt layers." These flows are currently the hardest aspect of Claude Code's configuration model to understand, and making them literal navigable paths in the diagram is the single most powerful teaching act the app can perform.

**Health propagation along edges.** A validation error in Parsing propagates a warning indicator along all downstream arrows, so the user can see at a glance that something upstream is affecting the end result. Tapping a propagated warning traces it back to its source node and then to the specific file or key that caused it.

**Progressive complexity via zoom level.** At the top-level overview, stage nodes show only headline metrics. At one level of zoom (inside a stage), the substructure is visible — files, keys, servers, hooks, layers. At two levels of zoom (inside a specific item within a stage), the full detail, annotations, and resolution traces are available. Users naturally explore as deep as their current question requires, then navigate back up. Learners spend most of their time at the top level, developing their mental model. Practitioners dive immediately to the specific key or hook they need.

**Technical approach in SwiftUI.** The top-level diagram is implemented as a `Canvas`-backed view or a custom `Layout` positioned over `ZStack`-arranged node views. `matchedGeometryEffect` coordinates the zoom-in/zoom-out animation between the compact overview node and the expanded detail view. Node positions and edge paths are computed from a fixed layout model (not Auto Layout), giving precise control over the visual composition. The existing per-stage ViewModels and detail views are unchanged — the diagram is a new navigation shell around them, not a replacement of their internal logic.

---

### 2b.2 Intention-Based Settings Editing

The conventional approach to configuration editing asks the user to understand the file structure before making any change: open the project scope, locate `settings.json`, find or add the right key, use the correct value format, understand how it interacts with the same key at the user or managed scope. This is exactly the expertise the app is designed to make unnecessary.

The intention-based editor inverts this. **The user works with resolved, logical settings — not files.** The app handles all file routing decisions.

**The editing interaction.** The user enters Edit Mode on the resolved settings view (a toolbar button, or a menu item). Every resolved setting row gains an edit affordance. Tapping a row opens a compact editor anchored to that row:

```
┌─────────────────────────────────────────────────────────┐
│  model                                                   │
│  Current value:  claude-sonnet-4-6                       │
│  Source:         User scope (~/.claude/settings.json)    │
│                                                          │
│  New value:      [ claude-opus-4-6            ▾ ]        │
│                                                          │
│  Save to:  ◉ Project scope    (recommended for teams)   │
│             ○ User scope      (applies to all projects)  │
│             ○ Project-local   (your personal override)   │
│                                                          │
│  Why recommended?  This setting affects all sessions in  │
│  this project. Saving here shares it with your team.     │
│                                                          │
│  [ Preview Impact ]          [ Save ]     [ Cancel ]     │
└─────────────────────────────────────────────────────────┘
```

The **"Save to" picker** is where the intelligence lives. The app pre-selects the recommended scope based on the setting's category and the current project context. It explains the recommendation in plain English. The user can override at any time — the recommendation is a suggestion, not a gate.

The **"Preview Impact" button** re-runs the full resolution pipeline in memory with the proposed change applied and presents a diff: the new effective value for this key, any other keys whose resolved values would change as a side effect, the updated waterfall showing the new winning scope, and a preview of the exact JSON that would be written to the target file. Nothing is written to disk until "Save" is confirmed.

**The "I don't care where it lives" shortcut.** For simple cases — a solo developer tuning their own configuration — the scope picker can be presented in a simplified two-option form: "This project only" or "All my projects." The underlying routing (project scope vs user scope) is the same; the language removes the need to know what "project scope" means. The full picker is available via "Show advanced options" for those who want control.

**Scope routing rules (implemented in the app's write layer):**

The app uses the same resolution rules it already computes, applied in reverse to determine the correct write target:

- If the setting is already defined at a writable scope, editing updates that scope's file as the default
- If the setting is not yet defined anywhere, the app recommends the most contextually appropriate scope based on the setting's registered category (personal preferences → user scope; project behaviour → project scope)
- If the setting is defined at a higher-precedence scope that the user cannot edit (managed or MDM), the edit affordance is replaced with a lock icon and the text "Set by managed policy — cannot be overridden at this level"
- If saving at the chosen scope would be immediately overridden by a higher-precedence scope that already defines the same key, the app warns before saving: "This value will be silently overridden by your managed settings and will have no effect. Consider changing the target scope or contacting your administrator."

**Write invariants enforced on every save:**

1. Parse the target file into memory, or create a valid empty JSON object if the file does not exist
2. Apply the change to the in-memory structure
3. Validate the resulting document against the schema-driven key registry: wrong types, illegal values, scope-restricted keys used at the wrong level
4. Validate the full resolved configuration with the change applied: detect semantic conflicts
5. If validation passes, serialize to canonical JSON formatting and write atomically (write to a temp file in the same directory, fsync, rename — no partial writes)
6. Re-run the full pipeline; if the post-write resolved state is inconsistent with the expected change, roll back and surface the failure
7. If validation fails at step 3 or 4, surface the specific errors with plain-English explanations and do not write

The editing experience should feel as frictionless as adjusting a preference in System Settings. The enforcement complexity is entirely the app's responsibility — invisible to the user unless something goes wrong, and when it does go wrong, the error is a sentence the user can act on, not a JSON parse error or a silent failure.

---

## Part 3: Feature Roadmap

Features are organized by theme, with each feature annotated by its primary audience (Learner / Practitioner / Admin), its implementation dependency chain, and a rough priority tier (P1 = foundational, P2 = high value, P3 = advanced).

---

### Theme Z: The Unified Interactive Diagram (Primary Navigation)

This theme defines the top-level experience of the app. Everything else in the roadmap feeds into or is reachable through this diagram. It is listed first because it should inform the design of every other feature, even if it is built incrementally.

**Z1 — Top-Level Pipeline Overview Diagram** `P1 · All audiences`
A `Canvas`-backed or custom `Layout`-driven view rendering all eight pipeline stages as connected node cards in a single, non-scrolling layout. Each card shows its stage name, a health indicator, a key metric, and scope contribution dots. Nodes are connected by directional arrows. The diagram replaces the current `TreePipelineOverviewStrip` as the primary entry point. Target: every stage is visible at once without scrolling on a standard 13" MacBook screen.

**Z2 — Animated Node Zoom with `matchedGeometryEffect`** `P1 · All audiences`
Tapping a stage node in the overview diagram animates the node expanding to fill the detail area, while remaining nodes compress into a breadcrumb strip. The back gesture or breadcrumb tap reverses the animation. All eight existing stage detail views (Discovery, Parsing, Resolution, Prompt Assembly, Tool Execution, Hooks Lifecycle, MCP, Context Budget) become the zoom-in destinations — their internal views are unchanged.

**Z3 — Navigable Cross-Stage Arrows** `P2 · Learner · Practitioner`
Tapping an edge (arrow) between two stage nodes opens a "flow panel" explaining what travels between those stages: which file objects flow from Discovery into Parsing, which parsed values flow into Resolution, which resolved values are consumed by Prompt Assembly. Each flow item in the panel is itself tappable, linking directly to its source or destination within the adjacent stage detail views.

**Z4 — Health Propagation Along Edges** `P2 · Practitioner · Admin`
Validation issues in an upstream stage propagate visual warning indicators along downstream edges. The user can trace a pipeline-wide health impact backward to its source with a single tap on the warning indicator. For example, a missing managed settings file surfaces as a warning on the Discovery → Parsing edge and on every downstream edge, with a "Show source" action that navigates to the relevant Discovery tree node.

**Z5 — Sub-Process Expansion Within Nodes** `P2 · Learner`
Within a zoomed-in stage view, complex stages (Resolution, Prompt Assembly) offer a "Show sub-processes" toggle that renders an intermediate level of diagram — for Resolution, this shows the three merge method paths (override, merge, deep merge) as parallel lanes with the relevant settings flowing down each lane; for Prompt Assembly, it shows the six layers stacking sequentially with token budgets. This is the "any part of which can be expanded to show the sub-processes" requirement, applied within individual stages.

**Z6 — Simplified Overview Mode (3-Stage)** `P2 · Learner`
A toggle in the toolbar collapses the eight-stage diagram into three composite nodes: "Your Files" (Discovery + Parsing), "The Rules" (Resolution + Permissions), and "What Claude Sees" (Prompt Assembly + Context Budget + MCP). Each composite node still zooms into its constituent stages. Default for new users; advanced mode is persistent once activated.

---

### Theme F2: Intention-Based Settings Editing (File-Routing Editor)

This theme covers the editing experience described in Part 2b.2. It is separated from the lower-level file editing features in Theme F to make clear that intention-based editing is the primary editing paradigm, and direct file editing is an advanced escape hatch.

**F2-1 — Edit Mode Toggle and Resolved Settings Editor** `P1 · Practitioner · Admin`
A toolbar "Edit" button enters Edit Mode on the resolved settings view. In Edit Mode, every setting row gains an inline edit affordance. The affordance is hidden or replaced with a lock icon for managed-controlled settings. Tapping the affordance opens the scoped editor popover described in Part 2b.2. Exiting Edit Mode (Save or Cancel) returns to read-only view.

**F2-2 — Scope Recommendation Engine** `P1 · Practitioner`
For each setting, the app computes a recommended save scope based on: whether the setting is already defined at any writable scope (default: update the existing scope); the setting's category metadata from the key registry (personal preference → user scope; project behaviour → project scope); and whether a higher-precedence scope already defines the same key (surface a warning). The recommendation is shown in plain English in the editor popover with a one-sentence rationale.

**F2-3 — Pre-Save Resolution Preview** `P1 · Practitioner`
Before any write, the app re-runs the full pipeline in memory with the proposed change applied and presents a structured diff: new effective value, list of other keys affected, updated waterfall for this key, and a preview of the target file's content after the change. The user must see this diff before confirming the save. The diff is presented as a human-readable comparison, not a raw JSON patch.

**F2-4 — Atomic Write with Rollback** `P1 · All audiences`
Every confirmed save writes atomically: parse target → apply change in memory → validate → serialize to canonical JSON → write to temp file → fsync → rename into place → re-run pipeline → verify. If the post-write pipeline state does not match the expected change, roll back (the original file is preserved until the rename succeeds) and surface the failure. No partial writes, no silent failures.

**F2-5 — Managed Lock Indicators** `P1 · Admin`
Settings owned by the managed tier display a lock icon in both read-only and Edit Mode. Tapping the lock shows: which managed tier controls this setting (server-managed / MDM / file-based), the file or policy domain that defines it, and the value it enforces. There is no edit affordance. This makes managed policy tangible and visible rather than a mystery.

**F2-6 — Override Conflict Warning** `P2 · Practitioner`
If the user selects a scope for saving that would be immediately overridden by a higher-precedence scope already defining the same key, the editor displays a prominent warning before "Save" becomes active: "This change will have no effect because [Managed scope / User scope] already sets this key to [value]. Change the save target or leave this key unchanged." Requires explicit acknowledgement to proceed.

**F2-7 — Simplified Scope Picker ("This project" / "All projects")** `P2 · Learner`
An alternative scope picker presenting only two options — "This project only" and "All my projects" — that routes to project scope and user scope respectively. Shown by default. Full scope picker available via "Advanced." Persistent preference once changed.

---

### Theme P: Pipeline Wiring and Foundation Repair

This theme contains no new features. It repairs the broken bridge between the parser layer and the resolver layer that is currently preventing any resolved configuration data from being produced. It must be completed before any other theme produces correct results.

**P1 — ConfigurationPipeline Document Wiring** `P1 · All audiences`
Complete the implementation of `buildResolverInputs()` in `ConfigurationPipeline.swift` so that each `SettingsSourceCandidate`, agent candidate, skill candidate, and CLAUDE.md candidate is created with its parsed document populated rather than `nil`. The parsed document for each file is already available from the parse step — it must be passed through to the candidate constructor. MCP candidates must also be appended (currently the `.mcpJson` case creates a source and discards it). Once wired, `resolvePrecedence()` will receive real data and the resolver will produce non-empty results for the first time outside the Managed scope view. The `ParseResultRecord` struct may need typed document fields added to carry the strongly-typed parsed documents alongside the existing `rawContent` and `rawTextContent` fields. All eight compiler warnings in the file are symptoms of the same incomplete wiring and must be resolved as part of this packet. The file must be committed to git on completion — it is currently untracked.

**P2 — Pipeline Integration Tests** `P1 · All audiences`
Add end-to-end pipeline tests that feed real settings fixture files through `ConfigurationPipeline` and assert that `resolvePrecedence()` returns non-empty entries with correct values, correct winning scopes, and correct provenance traces. These tests close the gap that allowed the nil-document bug to go undetected: the existing pipeline tests only exercise empty-scan scenarios and state transitions, not resolution output.

---

### Theme A: Parser Completeness and Accuracy

These features are prerequisites for everything else. A UI can only be as accurate as its underlying parsers.

**A1 — Settings Key Registry (Schema-Driven Parsing)** `P1 · All audiences`
Replace ad-hoc settings property parsing with a schema-driven registry (`SettingsKeyRegistry`, `SettingsKeyDefinition`) that covers the full documented settings surface. Each key carries typed metadata: key path, expected shape, scope restrictions, merge hints, managed-only status. The registry must cover nested object families including `sandbox`, `permissions`, `statusLine`, `fileSuggestion`, `worktree`, and plugin marketplace structures. Unknown keys continue to emit info-level issues for forward compatibility. This is the single most important infrastructure investment — it unblocks every other feature that reads settings. It should be designed with expansion and change of schema in mind- claude ai changes rapidly and if the core logic changes a new app may be needed but most of the changes will just require additions ot the schema

**A2 — Typed Accessor Layer** `P1 · All audiences`
Grouped typed accessors on top of the registry-backed store: model settings, permission settings, hook policy settings, MCP policy settings, plugin settings, sandbox settings, UI settings, worktree settings, memory settings. All existing parser tests must continue to pass.

**A3 — Hook Parser Correction and Expansion** `P1 · Practitioner · Admin`
Correct `timeout` to seconds (not milliseconds). Add `once` (boolean, skills-only), `shell` (`"bash"` or `"powershell"`), and handler types `http`, `prompt`, and `agent` alongside the existing `command` type. These are documented, active properties that the current parser silently discards.

**A4 — Attribution Model Expansion** `P2 · Practitioner`
The `attribution` setting is now an object with `commit` and `pr` string sub-keys. `includeCoAuthoredBy` is deprecated but must remain parseable for backward compatibility. Update parser and UI to show both forms.

**A5 — `~/.claude.json` Key Expansion** `P1 · Practitioner`
Add parsing for `teammateMode`, `autoConnectIde`, `autoInstallIdeExtension`, `editorMode`, `showTurnDuration`, `terminalProgressBarEnabled`, and other documented keys currently absent from the ClaudeJson parser.

**A6 — Sandbox Settings Family** `P1 · Admin`
Full first-class parsing of the `sandbox` nested object: `failIfUnavailable`, `allowUnsandboxedCommands`, `network.allowedDomains`, `network.httpProxyPort`, `network.socksProxyPort`, `enableWeakerNetworkIsolation`. These govern security-critical behavior and must be prominently validated and displayed.

---

### Theme B: Managed Settings Tier

The highest-precedence tier in the configuration hierarchy is currently uninspected. This is the most significant gap for the administrator audience.

**B1 — Managed File Discovery** `P1 · Admin`
Discover `/Library/Application Support/ClaudeCode/managed-settings.json`, `managed-settings.d/*.json` (merged lexicographically), `managed-mcp.json`, and `/Library/Application Support/ClaudeCode/CLAUDE.md`. Treat missing paths as normal; inaccessible paths as attributable discovery issues. Tolerate App Store sandbox restrictions gracefully.

**B2 — MDM/Plist Reading** `P2 · Admin`
Read MDM-delivered managed settings from the `com.anthropic.claudecode` preference domain. Normalize plist values to `JSONValue`. Feed through the same parser and validator pathways as file-based managed settings. Keep strictly read-only.

**B3 — Managed Tier Resolution with Correct Precedence** `P1 · Admin`
Implement the "first tier wins" gate correctly: server-managed settings win over MDM which wins over file-based. Only the file-based tier merges internally. Integrate the managed resolver as the highest-precedence tier in the main resolver. All existing resolver tests must remain green.

**B4 — Managed Scope UI** `P2 · Admin`
Replace the current managed placeholder with a fully functional Managed scope view showing the active managed tier, its source, the policies it enforces, and which settings it locks. Visually communicate the "locked by managed policy" state for any setting that cannot be overridden by lower scopes.

---

### Theme C: Resolution Visualization Depth

The waterfall visualization is the heart of the app. It needs to become interactive and explanatory.

**C1 — Resolution Trace Drill-Down** `P1 · Practitioner · Learner`
Tapping any resolved value anywhere in the app opens a Resolution Trace panel. The panel shows: the effective value prominently; a vertical timeline of every scope that had an opinion, ordered by precedence; the value each scope declared; whether it won, was overridden, or merged; and the merge rule applied in plain English. For array settings, show a merge diagram with color-coded scope contributions. This is the single most valuable user-facing feature not yet implemented.

**C2 — Human-Readable Merge Labels** `P1 · Learner`
Replace developer-internal merge method identifiers (`selectHighestPrecedence`, `appendUnique`, `deepMergeObject`) with user-facing labels: "Overrides (highest scope wins)", "Merges (all scopes combined)", "Deep merges (per-key precedence)". Show the developer label on hover or in expanded detail. Add a small icon per merge type for visual scanning.

**C3 — Conflict Highlighting and Filter** `P2 · Practitioner`
Badge any setting row where multiple scopes disagreed with a small "Resolved conflict" indicator. Add a "Conflicts only" filter to the settings list. In the trace drill-down, show competing values side by side with strikethrough on losers. This makes the settings list immediately actionable for debugging.

**C4 — Scope Contribution Summaries** `P2 · Practitioner`
Each scope's detail view shows three panels: "Settings this scope wins" (values where this scope is authoritative), "Settings this scope contributes to" (array/object merges), and "Settings this scope loses" (values declared but overridden). Derived entirely from existing projection data, no new resolution logic required.

**C5 — Scope Overlay Filter** `P3 · Practitioner`
A persistent toggle or picker on the Pipeline tab that highlights only the contributions from a selected scope throughout all eight stages simultaneously. "Show me what the project scope does" highlights project-sourced values green everywhere, dims all other values. Lets users trace a single scope's influence across the entire pipeline in one pass.

---

### Theme D: Teaching Annotations and Progressive Disclosure

**D1 — Stage Explanations and Contextual Help** `P1 · Learner`
Each of the eight pipeline stages should have a persistent explanation panel (collapsible, dismissable) that describes what happens at that stage in plain English: what Claude Code does, why it matters, what can go wrong, and how to influence it. These are not tooltips — they are paragraphs of genuine explanation, like documentation embedded in the visualization.

**D2 — Simplified 3-Stage View** `P2 · Learner`
An "Overview" mode that collapses the eight stages into three: "Your Files" (discovery + parsing), "The Rules" (resolution + permissions), and "What Claude Sees" (prompt assembly + context budget). An "Advanced" toggle expands to the full pipeline. Default the app to this view for new users. This lowers the barrier to entry dramatically.

**D3 — Animated Pipeline Introduction** `P3 · Learner`
On first launch (or on demand from a Help menu), a 5-10 second animation shows the pipeline flowing: files appearing, being parsed, values merging, the prompt assembling, the agent starting. This single animation conveys the core mental model more efficiently than any amount of static text.

**D4 — Merge Method Illustrated Examples** `P2 · Learner`
When a user first encounters a merge method badge, offer an expandable "Show example" link that renders a small before/after diagram: two scopes declaring different values, the merge rule applied, the effective result. These are static, illustrative examples embedded in the UI, not computed from real data.

**D5 — Instruction Load Order Annotation** `P2 · Learner`
In the Prompt Assembly stage, annotate each CLAUDE.md layer with its load order index (1, 2, 3...) and explain that later-loaded files have more contextual influence. Add a callout: "This file was loaded last and has the strongest influence on Claude's behavior in this session." This is the teaching moment the current UI most urgently needs.

**D6 — Permission Evaluation Illustrated Example** `P2 · Learner`
In the Tool Execution stage, add a static illustrative example showing the deny → ask → allow evaluation sequence with a specific hypothetical tool invocation. This teaches the evaluation order concretely without requiring the "What If" inspector to be built first.

---

### Theme E: The "What If" Inspector

The most powerful teaching and debugging tool the app could have.

**E1 — Permission Rule Simulator** `P2 · Practitioner · Learner`
A panel where the user types a hypothetical tool invocation (e.g., `bash: rm -rf node_modules` or `mcp__github__create_issue`) and the app traces it through their actual configured permission rules and hooks. Output: would it be allowed? Which rule matched? Which hook would fire? No code is executed — this is pure rule evaluation against the in-memory resolved configuration.

**E2 — Settings Change Impact Preview** `P2 · Practitioner`
The user selects a scope and a key, proposes a new value, and sees the downstream effect on the resolved configuration: which other keys this would change (if any), which scopes would now be overridden, and how the waterfall diagram would differ. No files are written until explicitly saved. This is the "what if I add model: opus to my project settings?" feature.

**E3 — CLAUDE.md Import Tracer** `P3 · Practitioner`
The user proposes adding an `@import` directive to a CLAUDE.md file and sees where the imported content would appear in the instruction load order, how many tokens it would consume, and how it would interact with existing instructions. Presents the resolved instruction stack with the hypothetical import included.

**E4 — MCP Server Removal Preview** `P3 · Practitioner`
The user selects an MCP server and sees which tools would disappear from Claude's capability set if that server were removed or blocked. Shows the tool count change and lists affected tools. Useful for evaluating the impact of policy changes before applying them.

---

### Theme F: Configuration Editing

The administration half of the app's dual purpose. All editing must validate before saving and write atomically.

**F1 — Settings Editor for User Scope** `P2 · Practitioner · Admin`
Inline editing of `~/.claude/settings.json` for any setting in the User scope. Validation before save with error and warning surfacing. Atomic write-through with file backup. Schema-driven: the editor knows which keys are valid, what types they accept, and what values are legal. No freeform JSON editing — structured field editing only.

**F2 — Settings Editor for Project Scope** `P2 · Practitioner`
Inline editing of `.claude/settings.json` and `.claude/settings.local.json` for a registered project. Same validation and atomic write behavior as F1. Clear visual distinction between team-shared (settings.json) and personal (settings.local.json) edits.

**F3 — CLAUDE.md Editor** `P2 · Practitioner`
A Markdown editor for CLAUDE.md files at any scope. Shows a live token count, a preview of where this file appears in the assembled prompt, and a word-wrap formatted view of the content. Saves atomically. Warns when a file approaches a size that would meaningfully consume context budget.

**F4 — MCP Server Editor** `P2 · Practitioner`
Add, edit, and remove MCP server definitions from `~/.claude.json` (user scope) and `.mcp.json` (project scope). Form-based editor with fields for server ID, transport type (stdio/http), command/URL, arguments, and environment variables. Validates completeness before saving.

**F5 — Hook Configuration Editor** `P3 · Admin`
Add, edit, and remove hook handlers for any lifecycle event (PreToolUse, PostToolUse, SessionStart, SessionEnd). Form-based editor with fields for event type, handler type (command/http/prompt/agent), timeout (in seconds), and optional matchers. Live validation against the hook schema.

**F6 — Permission Rule Editor** `P2 · Practitioner`
Add, edit, and remove entries in `permissions.allow`, `permissions.deny`, and `permissions.ask` arrays. Shows the effective merged rule list alongside the per-scope editors, so the user can see how their change affects the resolved state in real time (before saving). Supports glob patterns with syntax validation.

**F7 — Sandbox Configuration Editor** `P3 · Admin`
Structured editor for the `sandbox` family of settings. Fields for allowed domains, proxy settings, `failIfUnavailable`, and `allowUnsandboxedCommands`. Clear warnings when sandbox settings would restrict or expose capabilities in ways that may be unintended.

---

### Theme G: Configuration Snapshots and Profiles

**G1 — Configuration Snapshot Export** `P2 · Admin · Practitioner`
Export the current fully-resolved configuration state as a structured JSON or YAML document. Includes: all resolved settings with provenance, resolved instruction stacks, MCP server landscape, effective permission rules, and hook lifecycle. Suitable for documentation, audit, and sharing. Does not export auth tokens or sensitive runtime state.

**G2 — Named Configuration Profiles** `P3 · Admin`
Save the current settings for a scope as a named profile (e.g., "Strict Security Mode", "Full Development Access"). Profiles store only the settings for that scope, not the full resolved state. Profiles can be applied to a scope to restore its settings, or previewed as a change impact before applying. Profiles are stored in an app-owned file, not in Claude-owned config files.

**G3 — Configuration Diff View** `P3 · Practitioner`
Compare two snapshots side by side, or compare the current resolved state against a saved profile. Shows added, removed, and changed settings with color-coded diff styling. Useful for understanding the effect of a configuration change over time or between environments.

**G4 — Profile Sync via iCloud** `P3 · Admin`
Optional iCloud sync for named profiles, allowing a practitioner to maintain and apply consistent configurations across multiple Macs. Profiles contain only app-owned metadata and scope-specific settings — no Claude-owned auth tokens or sensitive state.

---

### Theme H: Dashboard and Navigation

**H1 — Configuration Overview Dashboard** `P1 · All audiences`
Replace the current cold-launch state with a Configuration Overview as the default view. Shows: health summary (scopes active, settings resolved, warnings, errors), a compact scope stack mini-visualization, recent conflicts (the 3-5 most interesting resolved disagreements), file discovery summary, and quick links to permissions, MCP, and hooks. This gives any user immediate orientation on launch.

**H2 — Global Settings Search** `P2 · Practitioner`
A persistent search bar (⌘F or toolbar) that searches across all resolved settings, all file paths, all MCP server names, and all hook event types. Results show the effective value, the winning scope, and a one-click navigation to the relevant pipeline stage and key. This is the fastest path to any piece of configuration information.

**H3 — Scope Stack Sidebar Navigation** `P2 · All audiences`
Restructure the sidebar from a flat list of four destinations into a visual Scope Stack: Managed (top, highest precedence), User, Project/Project-Local, Session/CLI (bottom). Each layer shows a file count badge, an issue badge, and an active/inactive state. The "Resolved Configuration" view sits below the stack as its output. This communicates the precedence hierarchy structurally rather than requiring the user to learn it.

**H4 — Keyboard Navigation** `P2 · Practitioner`
Arrow key navigation across the pipeline overview strip. Tab/Shift-Tab navigation within stage content. Keyboard shortcuts for common actions: ⌘1–8 for pipeline stages, ⌘R to refresh, ⌘E to open the settings editor, ⌘S to save. VoiceOver-complete with semantic labels on all custom controls.

**H5 — Two-Level Session Navigation** `P3 · Practitioner`
Replace the 7-segment picker in the Session view with a two-level navigation: a left list grouping by concern (Configuration: Settings, Permissions, Instructions, Hooks, MCP, Agents & Skills; Diagnostics: Transcripts, Usage, Issues), and a detail area. This scales as the feature set grows and organizes information by user intent rather than by data type.

---

### Theme I: Permissions Inspector (First-Class Feature)

Permissions are the highest-frequency source of user confusion in Claude Code configuration. They deserve their own dedicated view.

**I1 — Dedicated Permissions Inspector** `P2 · Practitioner · Learner`
A dedicated Permissions view (in both the Pipeline tab and the Session view) that shows the evaluation order diagram (Deny → Ask → Allow, first-match-wins), the effective rules table grouped by action type (file operations, shell commands, MCP tools), and per-rule provenance showing which scope contributed each rule and whether scopes merged.

**I2 — Permission Inheritance Tree** `P2 · Practitioner`
Visual tree showing how permission rules accumulate across scopes. Managed rules at the root, user rules in the middle, project and project-local rules as leaves. Array merge (appendUnique) is shown as entries flowing upward and accumulating. Makes it immediately clear which scope "owns" each rule.

**I3 — Permission Conflict Detection** `P2 · Admin`
Detect and surface logical conflicts in the permission rule set: deny rules that shadow allow rules, redundant entries, rules that match the same tool invocations with different outcomes. Present these as validation warnings with an explanation of the conflict and a suggested resolution.

---

### Theme J: Instruction (CLAUDE.md) Visualization

**J1 — Instruction Load Order Tree** `P2 · Learner · Practitioner`
Render CLAUDE.md composition as a visual tree: the session root, scope-level files as branches, imported files as leaves. Each node shows its file path, scope badge (colored by scope), discovery order index, and token count. Lines represent `@import` relationships. Node color or opacity encodes "influence strength" (later-loaded = stronger influence). Click a node to preview its content.

**J2 — Import Graph Cycle Detection** `P2 · Admin`
Detect circular `@import` chains and surface them as errors with the cycle path displayed. Show which file would not be loaded as a result and what content would be missing.

**J3 — Instruction Token Budget Warning** `P2 · Practitioner`
When the total instruction token count across all CLAUDE.md files exceeds a configurable threshold (e.g., 25% of the model's context window), surface a warning in the Prompt Assembly stage. Show which files are the largest contributors and suggest strategies for reduction.

**J4 — Instruction Content Full Preview** `P2 · Practitioner`
Expand any instruction layer in the Prompt Assembly stage to show its full content (not just the first 3 lines). Include line count, token count, and the source file path. Add a "Copy to clipboard" action and an "Edit this file" shortcut that opens the CLAUDE.md editor.

---

### Theme K: MCP Server Management

**K1 — MCP Server Card Redesign** `P2 · Practitioner`
Redesign MCP server entries as cards: server name as title, scope badge (colored pill), transport type icon (terminal for stdio, globe for HTTP), validation status (complete config vs. missing required fields), "overridden by" callout, and a collapsible detail section with full config and resolution trace.

**K2 — MCP Tool Catalog** `P2 · Learner · Practitioner`
For each active MCP server, list the tools it contributes to Claude's capability set alongside the 18 built-in tools. Show tool name, description, input schema summary, and source server. This makes the capability landscape concrete — users can see exactly what Claude can do in their configured environment.

**K3 — MCP Server Override Visualization** `P3 · Practitioner`
When user-scope and project-scope both define a server with the same ID, show the override relationship explicitly: which definition is active, which is suppressed, and what differs between them. Currently both are shown without explicit override markup.

**K4 — MCP Server Health Check** `P3 · Practitioner`
For stdio-based MCP servers, validate that the command exists at the specified path and is executable. For HTTP-based servers, validate the URL format. Surface missing or malformed configs as errors in the Parsing stage before they would cause a runtime failure.

---

### Theme L: Session and Runtime

**L1 — Live Session Binding** `P3 · Practitioner`
Connect to a currently-running Claude Code instance via its status-line JSON payload or transcript file to display live token consumption, the currently active tool, and the current hook execution state. Toggle between "live" and "estimated" modes in the Context Budget stage.

**L2 — Session Transcript Reader** `P2 · Practitioner`
A full-featured transcript viewer for `.jsonl` session files. Show each turn with role, content, tool use, tool results, and token usage. Allow jumping to any turn, searching within a transcript, and exporting a human-readable summary.

**L3 — Usage Analytics Dashboard** `P2 · Practitioner`
Aggregate usage data across multiple sessions and projects: total tokens, total cost, model distribution over time, most-used tools, sessions by project. Show trends over configurable time windows. All computed from local transcript files — no network access required.

**L4 — Subagent Session Visualization** `P3 · Practitioner`
Display the hierarchical relationship between parent and subagent sessions (from `~/.claude/projects/<key>/<session>/subagents/*.jsonl`). Show the subagent tree, each agent's task summary, token usage, and how the parent session consumed subagent results.

---

### Theme M: Validation Engine

**M1 — Schema Validation** `P1 · All audiences`
Validate all parsed settings against the schema-driven key registry: wrong types, values outside enumerated options, keys that are mutually exclusive, keys that are only valid at specific scopes. Surface issues with descriptive codes (`.invalidFieldType(key, expected, got)`) and actionable messages.

**M2 — Semantic Validation** `P2 · Practitioner · Admin`
Beyond schema: detect semantic issues such as permission deny rules that conflict with managed allow rules (and explain precedence), CLAUDE.md files that exceed recommended token budgets, MCP servers with missing authentication where authentication is required, sandbox settings that would block tools required by configured hooks.

**M3 — Validation Issue Aggregation View** `P2 · Practitioner`
A dedicated Issues view (in both the Pipeline tab and Session view Diagnostics section) listing all validation issues across all scopes, grouped by severity (error, warning, info). Each issue links to the pipeline stage and file where it was detected. A badge on the sidebar communicates issue count at a glance.

**M4 — Pre-Edit Validation Preview** `P2 · Practitioner`
Before any edit is committed to disk, run full schema and semantic validation against the proposed change and display the result. Prevent saves that introduce errors. Allow saves that introduce warnings with explicit user confirmation.

---

### Theme N: Accessibility and Polish

**N1 — Accessibility Pass** `P2 · All audiences`
VoiceOver labels on all custom controls, health badges, waterfall tier indicators, and pipeline stage nodes. Accessibility hints for non-obvious interactions (cross-stage navigation, popover triggers). Full keyboard navigation within all views.

**N2 — Scope Color Coding Consistency** `P1 · All audiences`
Apply consistent scope color coding throughout every visualization: Managed (red/amber), User (blue), Project (green), Project-Local (teal), CLI (purple). Use these colors in badges, waterfall tiers, tree nodes, instruction layers, and contribution summaries. This is the single highest-leverage visual consistency improvement — it lets users build scope intuition at a glance across the entire app.

**N3 — Responsive Popover Sizing** `P2 · All audiences`
Fix popover sizing for windows narrower than 500pt. Use adaptive presentation (sheet on narrow windows, popover on wide windows) for file detail and resolution trace panels.

**N4 — Card vs Table View Toggle** `P3 · Practitioner`
Offer a toggle between "card view" (current) and "table view" (compact, dense) for the settings list. Power users in reference-lookup mode benefit from seeing more settings per screen. Persist the preference.

**N5 — Monospace Copy-Paste for All Values** `P2 · Practitioner`
Ensure all key paths, file paths, setting values, and tool invocation strings are selectable and copyable. Add a copy icon or context menu item to any monospace value. This is a small change with high daily-use impact.

---

## Part 4: Implementation Sequence

The following sequence reflects dependencies, audience impact, and the principle of shipping value incrementally.

**Immediate prerequisite — pipeline repair (must complete before any resolution output is trustworthy):**
P1 (ConfigurationPipeline document wiring) → P2 (pipeline integration tests). Nothing downstream of the resolver produces correct results until P1 is done.

**Foundation — parser and managed tier (must complete before significant UI work):**
A1 → A2 (schema-driven registry and accessors) → A3 → A5 → A6 (hook, `~/.claude.json`, and sandbox parsers) → M1 → B3 (managed file discovery and tier resolution) → M1 (schema validation engine).

**Diagram shell (can begin in parallel with foundation — layout does not depend on parser completeness):**
Z1 (top-level diagram static layout with mock data) → Z2 (animated node zoom using existing stage views) → Z6 (simplified 3-stage mode) → Z3 (navigable cross-stage arrows) → Z4 (health propagation).

**High-value read-only UI (begin after foundation):**
N2 (scope colour coding — immediate, low-effort, highest-leverage visual improvement), C2 (human-readable merge labels), C1 (resolution trace drill-down — single most impactful user-facing feature), C3 (conflict highlighting), H1 (dashboard overview).

**Intention-based editing (begin after read-only core is trustworthy and validated):**
F2-4 (atomic write infrastructure) → F2-1 (Edit Mode toggle and resolved editor popover) → F2-2 (scope recommendation engine) → F2-3 (pre-save resolution preview) → F2-5 (managed lock indicators) → F2-6 (override conflict warning) → F2-7 (simplified scope picker). Direct file editors (F1–F7) are built on top of the same atomic write infrastructure and can follow as extended coverage.

**Teaching features (can run in parallel with high-value UI):**
D1 (stage explanations) → D5 (instruction load order annotation) → D2 (simplified view, superseded by Z6 if diagram is built first) → I1 (permissions inspector) → J1 (instruction load order tree) → Z5 (sub-process expansion within nodes).

**Advanced features (third phase):**
E1 → E2 (What If inspector, builds on resolution preview infrastructure from F2-3), G1 → G2 (snapshots and profiles), L1 (live session binding), L4 (subagent visualization), D3 (animated pipeline introduction), H4 (full keyboard navigation).

---

## Part 5: Principles to Preserve

Throughout all future development, the following principles must remain inviolable:

**Claude files are authoritative.** The app never creates a shadow database or persists computed state as if it were configuration. Resolved views are computed in memory and discarded. Only Claude-owned files on disk carry authority.

**Reads are always safe.** The read-only pipeline can be trusted to never modify the system it observes. This trust is the foundation of the app's teaching utility.

**Writes are always validated and atomic.** No edit is written to disk without full schema and semantic validation. Files are replaced atomically with backup semantics. A failed write never leaves a file in a partially-written state.

**Provenance is always first-class.** Every value in the resolved configuration knows where it came from. This provenance is always available one interaction deep, never buried.

**The managed tier is always highest authority.** The UI must always make it visually unambiguous when a value is locked by managed policy. Users must never be left confused about why a setting cannot be changed.

**The app is a teacher, not a gatekeeper.** Even when a configuration is dangerous or misconfigured, the app's job is to explain what is happening and why — not to silently correct it. Warnings and errors are explanatory, not blocking (except when writing would introduce errors to disk).

---

## Appendix: Feature Summary Matrix

| Feature                         | Theme | Priority | Audience     | Status                  |
| ------------------------------- | ----- | -------- | ------------ | ----------------------- |
| Pipeline Document Wiring Fix    | P     | P1       | All          | **In progress (broken)** |
| Pipeline Integration Tests      | P     | P1       | All          | Not started             |
| Top-Level Pipeline Diagram      | Z     | P1       | All          | Not started             |
| Animated Node Zoom              | Z     | P1       | All          | Not started             |
| Navigable Cross-Stage Arrows    | Z     | P2       | All          | Not started             |
| Health Propagation Along Edges  | Z     | P2       | Practitioner | Not started             |
| Sub-Process Expansion in Nodes  | Z     | P2       | Learner      | Not started             |
| Simplified 3-Stage Diagram Mode | Z     | P2       | Learner      | Not started             |
| Edit Mode + Resolved Editor     | F2    | P1       | Practitioner | Not started             |
| Scope Recommendation Engine     | F2    | P1       | Practitioner | Not started             |
| Pre-Save Resolution Preview     | F2    | P1       | All          | Not started             |
| Atomic Write with Rollback      | F2    | P1       | All          | Not started             |
| Managed Lock Indicators         | F2    | P1       | Admin        | Not started             |
| Override Conflict Warning       | F2    | P2       | Practitioner | Not started             |
| Simplified Scope Picker         | F2    | P2       | Learner      | Not started             |
| Settings Key Registry           | A     | P1       | All          | Planned (G1 packet)     |
| Typed Accessor Layer            | A     | P1       | All          | Planned (G2 packet)     |
| Hook Parser Correction          | A     | P1       | Practitioner | Planned (H1/H2 packets) |
| Managed File Discovery          | B     | P1       | Admin        | Planned (M1 packet)     |
| MDM Plist Reading               | B     | P2       | Admin        | Planned (M2 packet)     |
| Managed Tier Resolution         | B     | P1       | Admin        | Planned (M3 packet)     |
| Resolution Trace Drill-Down     | C     | P1       | All          | Not started             |
| Human-Readable Merge Labels     | C     | P1       | Learner      | Not started             |
| Conflict Highlighting           | C     | P2       | Practitioner | Not started             |
| Scope Contribution Summaries    | C     | P2       | Practitioner | Not started             |
| Stage Explanations              | D     | P1       | Learner      | Not started             |
| Simplified 3-Stage View         | D     | P2       | Learner      | Not started             |
| Animated Pipeline Intro         | D     | P3       | Learner      | Not started             |
| Permission Rule Simulator       | E     | P2       | All          | Not started             |
| Settings Change Impact Preview  | E     | P2       | Practitioner | Not started             |
| Settings Editor (User Scope)    | F     | P2       | Practitioner | Not started             |
| Settings Editor (Project Scope) | F     | P2       | Practitioner | Not started             |
| CLAUDE.md Editor                | F     | P2       | Practitioner | Not started             |
| MCP Server Editor               | F     | P2       | Practitioner | Not started             |
| Hook Configuration Editor       | F     | P3       | Admin        | Not started             |
| Permission Rule Editor          | F     | P2       | Practitioner | Not started             |
| Configuration Snapshot Export   | G     | P2       | Admin        | Not started             |
| Named Configuration Profiles    | G     | P3       | Admin        | Not started             |
| Configuration Diff View         | G     | P3       | Practitioner | Not started             |
| Overview Dashboard              | H     | P1       | All          | Not started             |
| Global Settings Search          | H     | P2       | Practitioner | Not started             |
| Scope Stack Sidebar             | H     | P2       | All          | Not started             |
| Dedicated Permissions Inspector | I     | P2       | All          | Not started             |
| Instruction Load Order Tree     | J     | P2       | All          | Not started             |
| Full Instruction Preview        | J     | P2       | Practitioner | Not started             |
| MCP Tool Catalog                | K     | P2       | All          | Not started             |
| MCP Server Health Check         | K     | P3       | Practitioner | Not started             |
| Live Session Binding            | L     | P3       | Practitioner | Not started             |
| Session Transcript Reader       | L     | P2       | Practitioner | Not started             |
| Usage Analytics Dashboard       | L     | P2       | Practitioner | Not started             |
| Schema Validation Engine        | M     | P1       | All          | Planned (V1/V2 packets) |
| Semantic Validation             | M     | P2       | All          | Planned (V3/V4 packets) |
| Validation Issue Aggregation    | M     | P2       | All          | Not started             |
| Scope Color Coding              | N     | P1       | All          | Not started             |
| Accessibility Pass              | N     | P2       | All          | Not started             |
| Keyboard Navigation             | N     | P2       | Practitioner | Not started             |

---

_This document should be treated as a living reference. As packets are completed and the implementation plan evolves, update the status column and refine priorities based on user feedback and technical discoveries._

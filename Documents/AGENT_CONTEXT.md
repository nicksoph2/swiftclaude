# AGENT_CONTEXT.md
## Claude Config Manager — Compact Briefing for AI Agents

> **Read this file first.** It is a complete, self-contained briefing.
> All older design and handoff documents are archived in `Documents/Original Build Documents/`.
> Packet implementation specs are in `Documents/packets/`.
> Next-agent handoff for session capture and what-if: `Documents/NEXT-AGENT-HANDOFF.md`.
> Last updated: 3 April 2026.

---

## 1. What this app is

A native macOS 14+ SwiftUI app that reads, parses, resolves, and displays the full
Claude Code configuration surface — across Managed, User, Project, and Session scopes —
read-only, with full provenance. An interactive 8-stage pipeline visualization is the
primary UI. Limited editing is implemented (settings files, CLAUDE.md) via atomic writes.

The **owner's current focus is appearance and UI improvement.** Prefer visual polish,
layout, and interaction quality work over new infrastructure.

---

## 2. Build and test commands

Run from inside `ClaudeConfigManager/` (where `ClaudeConfigManager.xcodeproj` lives):

```bash
# Build only
xcodebuild build -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager \
  -destination 'platform=macOS' -quiet

# Full test suite — always run after any change
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager \
  -destination 'platform=macOS' -quiet 2>&1 | tail -30
```

**All tests must pass after every change. Never break existing tests.**

---

## 3. XcodeGen — mandatory rule for adding files

`ClaudeConfigManager/project.yml` is the sole source of truth for the Xcode project.

- **Never edit `project.pbxproj` directly.** It is generated.
- After creating new `.swift` files: **ask the user to run `xcodegen generate`** from `ClaudeConfigManager/`. Do not run it yourself.
- `Features/` uses folder references — new files there are picked up automatically after regeneration.
- "Cannot find type X in scope" after adding files = XcodeGen has not been re-run.
- Every new type name must be unique across the module — grep before naming.

---

## 4. Project source structure

```
ClaudeConfigManager/                    ← All Swift source
│
├── App/                                ← @main, routing, sidebar
│   ├── ClaudeConfigManagerApp.swift
│   ├── AppRouter.swift
│   ├── RootSplitView.swift
│   ├── SidebarView.swift (implied)
│   ├── SidebarDestination.swift
│   ├── SidebarState.swift
│   └── AppBootstrapState.swift
│
├── Core/                               ← Shared models and constants
│   ├── Models/
│   │   ├── TreePipelineModels.swift    ← PipelineStage, StageHealth, all tree data models
│   │   ├── OTelConfigModels.swift
│   │   ├── RuntimeSessionSnapshot.swift
│   │   ├── ScopeScreenModel.swift
│   │   └── UsageModels.swift
│   ├── ScopeColorScheme.swift          ← ONLY source of scope colours — never hard-code
│   ├── TokenEstimator.swift
│   ├── BuiltInToolCatalog.swift
│   ├── HookLifecycleTemplate.swift
│   └── PromptLayerConstants.swift
│
├── Features/
│   ├── Tree/                           ← Primary UI: 8-stage pipeline visualization
│   │   ├── TreePipelineView.swift      ← Top-level tree view, @SceneStorage collapse
│   │   ├── TreePipelineViewModel.swift ← @MainActor ObservableObject, weak pipeline ref
│   │   ├── TreePipelineOverviewStrip.swift  ← placeholder strip (target for replacement)
│   │   ├── PipelineDiagramView.swift   ← Main diagram entry point
│   │   ├── PipelineSimplifiedView.swift     ← Simplified/overview mode
│   │   ├── PipelineZoomedView.swift         ← Zoomed-in stage detail mode
│   │   ├── PipelineBreadcrumbStrip.swift    ← Navigation breadcrumb
│   │   ├── DiagramLayout.swift         ← Layout logic for diagram nodes
│   │   ├── DiagramEdgeFlow.swift       ← Edge/arrow drawing between nodes
│   │   ├── FlowPanelView.swift         ← Flow panel container
│   │   ├── StageExplanationView.swift  ← Teaching annotations per stage
│   │   ├── ResolutionTracePanelView.swift
│   │   ├── ResolutionWaterfallView.swift
│   │   ├── ResolutionSubProcessView.swift
│   │   ├── MergeMethodExampleView.swift
│   │   ├── ParsedFileCardView.swift
│   │   ├── PermissionEvaluationWalkthroughView.swift
│   │   ├── TreeDiscoveryView.swift + ViewModel
│   │   ├── TreeParsingView.swift + ViewModel
│   │   ├── TreeResolutionView.swift + ViewModel
│   │   ├── TreePromptAssemblyView.swift + ViewModel
│   │   ├── TreeToolExecutionView.swift + ViewModel
│   │   ├── TreeHooksLifecycleView.swift + ViewModel
│   │   ├── TreeMCPView.swift + ViewModel
│   │   └── TreeContextBudgetView.swift + ViewModel
│   │
│   ├── Managed/ManagedScopeView.swift
│   ├── User/                           ← UserScopeView, UserSettingsEditorView, SandboxConfigEditorView
│   ├── Project/                        ← ProjectScopeView, ProjectSettingsEditorView
│   ├── Session/                        ← SessionScopeView, UsageDashboardView, UsageAnalyticsDashboardView,
│   │                                      UsageDetailView, TranscriptReaderView, RuntimeSessionCardView,
│   │                                      PromptHistoryView, SubagentTreeView
│   ├── Permissions/                    ← PermissionsInspectorView, PermissionRuleEditorView
│   ├── Instructions/                   ← InstructionTreeView, ClaudeMdEditorView
│   ├── MCP/                            ← MCPServerCardView, MCPServerEditorView, MCPToolCatalogView
│   ├── Hooks/                          ← HookHandlerEditorView
│   ├── Search/                         ← GlobalSearchView, GlobalSearchViewModel
│   ├── Dashboard/                      ← ConfigurationDashboardView
│   ├── Diff/                           ← ConfigurationDiffView
│   ├── Snapshot/                       ← ProfileManagerView, SnapshotExportView
│   ├── WhatIf/                         ← WhatIfInspectorView, SettingsChangeImpactView
│   ├── Issues/                         ← IssuesView
│   ├── Help/                           ← HelpSearchView
│   ├── ConfigGrid/                     ← Config Grid view (function-grouped settings × scope columns)
│   │   ├── ConfigGridView.swift
│   │   ├── ConfigGridViewModel.swift
│   │   └── FunctionalGroupDefinitions.swift
│   ├── FlowStrip/                      ← Flow Strip + Session Timeline views
│   │   ├── FlowStripView.swift         ← Phase-by-phase pipeline view
│   │   ├── FlowStripViewModel.swift
│   │   ├── SessionTimelineView.swift   ← Chronological exchange narrative (5 acts)
│   │   └── SessionTimelineViewModel.swift
│   ├── Onboarding/                     ← PipelineIntroAnimationView (first-launch animated intro)
│   ├── Preferences/                    ← (folder exists, currently empty)
│   └── Shared/                         ← Reusable components:
│                                          ManagedLockPopover, PreSavePreviewView,
│                                          SettingEditorPopover, SettingsViewStyleToggle,
│                                          SimplifiedScopePicker, ScopeContributionSummaryView,
│                                          ScopePlaceholderView, ProjectSettingsEditorSheet,
│                                          UserSettingsEditorSheet,
│                                          ScopeChipView, ValueCellView, OriginBreadcrumbView
│
└── Infrastructure/
    ├── Pipeline/ConfigurationPipeline.swift  ← ✅ Full 5-phase impl (sole pipeline file)
    ├── Parsers/                        ← SettingsParser, SettingsKeyRegistry,
    │                                      SettingsDocumentValue+Accessors, SettingsValidator,
    │                                      ClaudeJsonParser, ClaudeJsonValidator,
    │                                      AgentParser, SkillParser, TranscriptParser,
    │                                      SemanticValidator, MCPServerHealthChecker
    ├── Discovery/                      ← RootLocator, WorkspaceScanner, ManagedFileLocator,
    │                                      RuntimeSessionDiscovery, UsageAggregator,
    │                                      OTelConfigDetector, RealHomeDirectory,
    │                                      RootResolutionModels
    ├── Resolver/ResolverModels.swift   ← SessionProjection + all resolver types
    ├── Bookmarks/                      ← BookmarkStore, BookmarkModels,
    │                                      BookmarkPersistence, FolderSelectionService
    ├── Snapshot/ConfigurationSnapshotExporter.swift
    ├── Debug/AppDebugMonitor.swift
    ├── AtomicFileWriter.swift
    ├── EditModeSupport.swift
    ├── FileBackupStore.swift
    ├── JSONKeyPathMutator.swift
    ├── LiveSessionWatcher.swift
    ├── PermissionRuleSimulator.swift
    ├── PipelinePreviewTypes.swift
    ├── ProfileStore.swift
    └── ScopeRecommendationEngine.swift

ClaudeConfigManagerTests/              ← 49+ test files
├── Parsers/                           ← 11 parser test files
├── Pipeline/                          ← ConfigurationPipelineTests, IntegrationTests,
│                                         DiagramEdgeFlowTests, PipelineDiagramViewTests,
│                                         StageExplanationTests, TreePipelineZoomTests
├── Resolver/                          ← ResolverModelsTests, ScopeColourAndResolutionUITests
├── Session/                           ← LiveSessionWatcherTests, RuntimeSessionDiscoveryTests,
│                                         UsageAggregatorTests, UsageModelsTests, SubagentTreeViewModelTests,
│                                         SettingsFamilyClassifierTests
├── Infrastructure/                    ← AtomicFileWriter, ConfigurationDiff, Snapshot,
│                                         PermissionRuleSimulator, ProfileStore, ScopeRecommendationEngine
├── Managed/                           ← ManagedScopeInspectorTests
├── Discovery/                         ← (scanner and locator tests)
├── Bookmarks/                         ← BookmarkStore, BookmarkExpansion
└── Fixtures/                          ← Test data: input/ and expected/ dirs per case
```

---

## 5. Architecture rules

| Rule | Detail |
|------|--------|
| Scope colours | Only `Core/ScopeColorScheme.swift`. Never hard-code. |
| Parsers | Never throw. Return `ParseResult<T>` (typed value + issues array). |
| Untyped JSON | `JSONValue` everywhere — never `Any`. |
| File writes | Always atomic: write temp → `fsync` → `rename`. Use `AtomicFileWriter`. |
| Observable classes | `@MainActor` on all `ObservableObject` state classes. |
| DI | Protocol-based. Stubs/mocks in test target only, never main target. |
| ViewModel/Pipeline | `weak var pipeline` in all ViewModels. Combine observation pattern. |
| Issue codes | Descriptive: `.invalidFieldType(key, expected, got)` not `.invalidField`. |
| File naming | `<Purpose><Layer>.swift` e.g. `ManagedSettingsLocator.swift` |
| Test files | `<TestedType>Tests.swift` |
| Fixtures | `Fixtures/<parser>/<case_id>/input/` and `expected/` |

---

## 6. Scope colours (reference)

```swift
// ScopeColorScheme.color(for:)
.managed      → .red
.user         → .blue
.project      → .green
.projectLocal → .teal
.session      → .orange
.cli          → .purple
```

---

## 7. Data flow

```
Disk files
  → WorkspaceScanner (Discovery)
  → Parsers → ParseResult<T>
  → Resolver inputs assembled
  → Individual Resolvers (Settings, Hook, MCP, Agent, Skill, Instruction)
  → SessionProjectionBuilder → SessionProjection
  → ConfigurationPipeline @Published projection
  → ViewModels (Combine, weak pipeline ref)
  → SwiftUI Views
```

`SessionProjection` in `Infrastructure/Resolver/ResolverModels.swift` is the central
merged view — every scope view reads from it.

Pipeline phases (in `Infrastructure/Pipeline/ConfigurationPipeline.swift`):
1. Discovery → WorkspaceScanner.scan()
2. Parsing → all parsers run on discovered files
3. Build inputs → assemble resolver inputs from parse results
4. Resolve → all individual resolvers run
5. Project → SessionProjectionBuilder.build(from:) → SessionProjection

---

## 8. Current app state (as of early April 2026)

**Working:**
- 8-stage pipeline visualization (Discovery, Parsing, Resolution, Prompt Assembly,
  Tool Execution, Hooks Lifecycle, MCP Servers, Context Budget)
- File discovery across all scope tiers with security-scoped bookmarks
- All major parsers (settings, CLAUDE.md, claude.json, agents, skills, MCP, transcripts)
- Settings Key Registry (74+ documented keys) with typed accessor layer
- Resolution waterfall with tracing and drill-down panel
- Edit mode (settings.json, CLAUDE.md) with atomic writes and scope recommendation
- Permissions inspector with rule simulation
- Global search (⌘F)
- Usage analytics and transcript parsing
- Profile snapshots and configuration export
- First-launch animated pipeline intro (PipelineIntroAnimationView)
- Diagram view work underway (DiagramLayout, DiagramEdgeFlow, PipelineZoomedView, PipelineSimplifiedView)

- Config Grid (⌘6) — function-grouped settings table with scope columns, override visibility
- Flow Strip (⌘7) — phase-by-phase view of pipeline with source cards, merge strips, budget bar
- Session Timeline (⌘8) — chronological 5-act narrative of a Claude exchange
- Shared components: ScopeChipView, ValueCellView, OriginBreadcrumbView

**Known gaps:**
- `TreePipelineOverviewStrip` is a basic placeholder — target for replacement by the
  Unified Interactive Diagram (see §9 below)
- Authorize buttons for `/etc/claude-code/` and `~/.claude.json` bookmarks not yet
  surfaced in the UI (infrastructure exists in BookmarkStore)
- Accessibility pass incomplete on some popover sizing at <500pt window width
- `Features/Preferences/` folder exists but is empty — no preferences UI yet
- Live Claude session binding (UI exists, backend stub only)
- Session capture/replay not yet implemented (see `Documents/NEXT-AGENT-HANDOFF.md`)
- What-If simulator views exist but may be stubs (see `Documents/NEXT-AGENT-HANDOFF.md`)

---

## 9. UI and appearance work — priority themes

The owner's focus. Key areas from the roadmap:

**Theme Z — Unified Interactive Diagram** (highest priority)
Replace `TreePipelineOverviewStrip` with a Canvas-backed or custom-Layout diagram
showing all 8 stages as connected node cards in a single non-scrolling view.
Work is in progress: `DiagramLayout.swift`, `DiagramEdgeFlow.swift`,
`PipelineDiagramView.swift`, `PipelineSimplifiedView.swift`, `PipelineZoomedView.swift`.
Spec: `Documents/packets/11-diagram-static-layout.md` through `15-resolution-trace-drilldown.md`

**Theme N — Visual Consistency**
- N2: Consistent scope colour coding everywhere — Managed=red/amber, User=blue,
  Project=green, Project-Local=teal, CLI=purple. Use `ScopeColorScheme` throughout.
- N3: Adaptive popover sizing — sheet on <500pt windows, popover on wider windows.

**Other UI work in scope:**
- Resolution waterfall interactivity (tap resolved value → trace panel)
- Managed scope lock indicators (which settings are locked by policy)
- Teaching annotations per pipeline stage (StageExplanationView exists)
- Instruction tree visual (CLAUDE.md as interactive tree)

---

## 10. Documents and where to find things

```
Documents/
├── AGENT_CONTEXT.md                  ← This file — read first
├── NEXT-AGENT-HANDOFF.md             ← Session capture & what-if handoff for next agent
├── UI-REDESIGN-SPEC.md               ← Spec for Config Grid, Flow Strip, Session Timeline
├── packets/                          ← Per-feature implementation specs (01–32)
│   └── NN-<name>.md                  ← Read the relevant packet before implementing
├── Screenshots/                      ← App screenshots (dashboard, pipeline, etc.)
└── Original Build Documents/         ← Archived reference docs
    ├── VISION_AND_ROADMAP.md         ← Full feature vision and theme descriptions
    ├── APP_ARCHITECTURE.md           ← Deeper technical reference, parser/resolver APIs
    ├── MASTER_TASK_LIST.md           ← Exhaustive prioritised task list
    ├── HELP-SCREENSHOT-SETUP.md      ← UI test screenshot automation guide
    ├── Claude Settings in the Enterprise.md  ← Enterprise context
    └── NN-handoff.md (×11)           ← What was built in each completed packet
```

**Completed packets** (handoff docs exist in Original Build Documents/):
03, 04, 05, 09, 10, 17, 18, 21, 23, 31 (bookmark expansion), 32

**Not yet started:** 01, 02, 06–08, 11–16, 19–20, 22, 24–31
(Note: several of these — e.g. diagram packets 11–15 — appear partially underway
based on new files in Features/Tree/)

---

## 11. Files safe to delete

- `ClaudeConfigManager.xcodeproj.delete.xcodeproj/` — empty remnant at project root

---

*Update this file at the end of each working session to reflect what changed.*

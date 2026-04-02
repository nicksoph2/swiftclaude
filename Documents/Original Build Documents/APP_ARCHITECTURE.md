# APP_ARCHITECTURE.md
## Claude Config Manager — Technical Reference for AI Agents

> Read this alongside `VISION_AND_ROADMAP.md`. Together they give a complete picture of what exists today and where the app is going.

---

## 1. Essential Context

- **Platform**: macOS 14+, Swift 5.9+, SwiftUI
- **Xcode project**: `ClaudeConfigManager.xcodeproj`
- **File registration**: The project uses **XcodeGen** (`project.yml`) as the source of truth. Do NOT edit `project.pbxproj` manually. To add new Swift files, create them on disk and add entries to `project.yml`, then regenerate. Alternatively, use folder references — the `Features/` subtree uses them.
- **Xcode MCP tools**: Use `mcp__xcode__*` for all Xcode project interactions. The tab identifier changes each session — always call `XcodeListWindows` first to get the current value.
- **Documents/ folder**: Not tracked in the Xcode project. Use bash or Write/Edit tools directly. XcodeWrite/XcodeRM will not work for files here.

---

## 2. Build and Test

```bash
# Build only
xcodebuild build -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager \
  -destination 'platform=macOS' -quiet

# Full test suite (always run after changes)
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager \
  -destination 'platform=macOS' -quiet 2>&1 | tail -30
```

**Never break existing tests.** Run the full suite after every change.

---

## 3. Top-Level Folder Structure

```
ClaudeConfigManager/
├── App/                          # App entry, routing, sidebar
├── Core/
│   ├── Models/                   # Shared model types (TreePipelineModels, etc.)
│   └── ScopeColorScheme.swift    # Single source of truth for scope colours
├── Features/
│   ├── Tree/                     # Main pipeline tree view and view model
│   ├── Managed/                  # Managed-scope view
│   ├── User/                     # User-scope view
│   ├── Project/                  # Project-scope view
│   └── Session/                  # Session-scope view
└── Infrastructure/
    ├── ConfigurationPipeline.swift        # ⚠️ STUB — currently IN Xcode project
    ├── Pipeline/
    │   └── ConfigurationPipeline.swift    # ✅ FULL implementation — NOT yet in project
    ├── Parsers/                   # All file parsers
    ├── Resolver/                  # Resolution models and merge logic
    ├── Discovery/                 # File discovery and root resolution
    └── Bookmarks/                 # macOS security-scoped bookmark management

ClaudeConfigManagerTests/
├── Parsers/                      # Parser unit tests
├── Discovery/                    # Scanner and locator tests
├── Bookmarks/                    # Bookmark store tests
└── Fixtures/                     # Test data: input/ and expected/ subdirs per case

Documents/                        # Design docs (not in Xcode project)
├── VISION_AND_ROADMAP.md         # Master vision and feature roadmap
├── APP_ARCHITECTURE.md           # This file
└── CLEANUP_PROMPT.md             # Agent prompt for pipeline consolidation
```

---

## 4. App Shell

| File | Role |
|------|------|
| `App/ClaudeConfigManagerApp.swift` | `@main` entry point, scene setup |
| `App/AppRouter.swift` | Top-level navigation state (`@MainActor ObservableObject`) |
| `App/RootSplitView.swift` | `NavigationSplitView` shell; sidebar + detail |
| `App/SidebarView.swift` | Sidebar list; drives `AppRouter.selection` |

The sidebar has entries for each scope (Managed, User, Project, Session) plus the pipeline Tree view.

---

## 5. Core Layer

### 5a. ScopeColorScheme
`Core/ScopeColorScheme.swift`

Single source of truth for all scope colours. **Never hard-code scope colours elsewhere.**

```swift
enum ScopeColorScheme {
    static func color(for scope: ResolutionScope) -> Color
    // .managed → .red  .user → .blue  .project → .green
    // .projectLocal → .teal  .session → .orange  .cli → .purple
    static func scopeBadge(for scope: ResolutionScope) -> some View
}
```

### 5b. TreePipelineModels
`Core/Models/TreePipelineModels.swift`

```swift
enum PipelineStage: CaseIterable {
    case discovery, parsing, resolution, promptAssembly,
         toolExecution, hooksLifecycle, mcpServers, contextBudget
    var title: String { … }
    var icon: String { … }   // SF Symbol name
    var sortOrder: Int { … }
}

enum StageHealth {
    case healthy, warnings(Int), errors(Int), noData
}

struct DiscoveryTreeNode { … }   // one node per discovered config file
struct ParsedFileEntry { … }     // parser output summary per file
struct ResolvedKeyEntry { … }    // one winning value + provenance per key
struct ScopeParticipant { … }    // which scopes contributed to a key
enum ParticipationKind { … }     // winning / overridden / shadowed / absent

struct PromptLayer { … }         // prompt assembly output
struct TreeNavigationTarget {    // cross-stage scroll destination
    var targetStage: PipelineStage { … }
    var anchorID: String { … }
}
```

---

## 6. Infrastructure Layer

### 6a. ⚠️ Dual Pipeline Files (CRITICAL — must be resolved)

There are currently **two files** both declaring `ConfigurationPipeline`:

| File | Lines | Status | Content |
|------|-------|--------|---------|
| `Infrastructure/ConfigurationPipeline.swift` | ~107 | **In Xcode project** | Stub — delegates to `ConfigurationPipelineRunner`, returns empty `SessionProjection` |
| `Infrastructure/Pipeline/ConfigurationPipeline.swift` | ~541 | **Not in Xcode project** | Full 5-phase implementation |

**The fix** (see `Documents/CLEANUP_PROMPT.md` for full step-by-step):
1. Delete (XcodeRM) the stub at `Infrastructure/ConfigurationPipeline.swift`
2. Register the full implementation at `Infrastructure/Pipeline/ConfigurationPipeline.swift` (add to `project.yml` or use XcodeGen)
3. Resolve any duplicate type declarations (`PipelineState`, `ConfigFileType`, `ParseResultRecord` are defined in both)
4. Fill the `SessionProjectionBuilder.build(from:)` gap if needed

Both files expose the same public API, so callsites should not need changes.

### 6b. Parsers
`Infrastructure/Parsers/`

All parsers follow the `ParseResult<T>` pattern:
```swift
// Parsers NEVER throw. They return a value + issues array.
struct ParseResult<T> {
    let value: T
    let issues: [SyntaxIssue]
}
```

| Parser | File type parsed |
|--------|-----------------|
| `SettingsParser` | `settings.json` |
| `ClaudeJsonParser` | `.claude.json` (MCP servers, etc.) |
| `AgentParser` | Agent definition files |
| `SkillParser` | Skill definition files |
| `ClaudeMdParser` | `CLAUDE.md` instruction files |

All parsers preserve unknown fields in raw form (`JSONValue`) for forward compatibility.
`JSONValue` is the project-standard untyped JSON enum — never use `Any`.

Issue codes must be descriptive: `.invalidFieldType(key, expected, got)` not just `.invalidField`.

### 6c. Resolver
`Infrastructure/Resolver/ResolverModels.swift` (~900 lines)

Contains all resolution types and logic:

```swift
enum ResolutionScope { case managed, user, project, projectLocal, session, cli }
enum MergeMethod { … }
struct ResolutionSource { … }
struct SettingsSourceTier { … }
struct SettingsSourceCandidate { … }
struct ResolvedSettingsSnapshot { … }
struct ResolvedSettingsEntry { … }   // winning value + full provenance chain
struct ResolvedHookSnapshot { … }
struct ResolvedMcpSnapshot { … }
struct ResolvedAgentSnapshot { … }
struct ResolvedSkillSnapshot { … }
struct InstructionResolverInput { … }
struct ResolvedInstructionSnapshot { … }

struct SessionProjection {           // the single merged view of all config
    var settings: ResolvedSettingsSnapshot
    var hooks: ResolvedHookSnapshot
    var mcpServers: ResolvedMcpSnapshot
    var agents: ResolvedAgentSnapshot
    var skills: ResolvedSkillSnapshot
    var instructions: ResolvedInstructionSnapshot
}

struct SessionProjectionBuilder {
    func build(from inputs: …) -> SessionProjection
}
```

Individual resolvers: `SettingsResolver`, `HookResolver`, `MCPResolver`, `AgentResolver`, `SkillResolver`, `InstructionResolver`.

Merge priority (highest wins): **Managed > User > Project > Session > CLI flag**

### 6d. Discovery
`Infrastructure/Discovery/`

| Type | Role |
|------|------|
| `RootLocator` | Finds Claude root directories (`~/.claude`, project `.claude/`, etc.) |
| `WorkspaceScanner` | Walks directory tree, enumerates config files by type |

The `WorkspaceScanner` discovers files across three managed-scope locations: the primary macOS path (`/Library/Application Support/ClaudeCode/`), the cross-platform path (`/etc/claude-code/`), and MDM policy domains. Both managed locations support `managed-settings.json`, `CLAUDE.md`, and `rules/*.md` discovery. The `ManagedSettingsLocator` holds path constants for both roots.

### 6e. Bookmarks
`Infrastructure/Bookmarks/BookmarkStore.swift`

macOS security-scoped bookmarks for persistent cross-launch folder access. Required because the app is sandboxed.

The bookmark system manages five kinds of access:

| BookmarkKind | ID Constant | Purpose |
|---|---|---|
| `globalClaudeRoot` | `global-claude-root` | `~/.claude/` directory |
| `managedClaudeCodeRoot` | `managed-claude-code-root` | `/Library/Application Support/ClaudeCode/` |
| `userClaudeJson` | `user-claude-json` | `~/.claude.json` file (sibling to `~/.claude/`, needs its own bookmark) |
| `etcClaudeCodeRoot` | `etc-claude-code-root` | `/etc/claude-code/` directory |
| `projectRoot` | `project-<hash>` | Per-project root directories |

`RootSelectionViewModel` exposes authorize/clear actions and published boolean flags (`hasAuthorizedUserClaudeJson`, `hasAuthorizedEtcClaudeCodeRoot`) for each bookmark kind, following the same pattern as the global and managed root bookmarks.

### 6f. Full Pipeline (5 phases)
`Infrastructure/Pipeline/ConfigurationPipeline.swift` (541 lines — to be registered)

```
Phase 1: Discovery      → WorkspaceScanner.scan()
Phase 2: Parsing        → all parsers run on discovered files
Phase 3: Build inputs   → assemble resolver inputs from parse results
Phase 4: Resolve        → all individual resolvers run
Phase 5: Project        → SessionProjectionBuilder.build(from:) → SessionProjection
```

Published state:
```swift
@Published private(set) var projection: SessionProjection?
@Published private(set) var scanResult: ScanResult?
@Published private(set) var parseResults: [ParseResultRecord]
```

Public API: `func run() async` — triggers a full pipeline refresh.

---

## 7. Features Layer

### 7a. Tree Pipeline View (primary view)
`Features/Tree/`

| File | Role |
|------|------|
| `TreePipelineView.swift` | Main SwiftUI view. `@SceneStorage("treeCollapsedStages")` for collapse persistence. Two-phase cross-stage scroll (350 ms delay). |
| `TreePipelineViewModel.swift` | `@MainActor ObservableObject`. `weak var pipeline`. `bind(to:)` method. Combine observation. |
| `TreePipelineOverviewStrip.swift` | Horizontal summary strip at top of tree. **Target for replacement by Theme Z Unified Interactive Diagram.** |

Cross-stage scroll pattern:
```swift
// Phase 1: scroll to stage header
// wait 350 ms for layout
// Phase 2: scroll to specific anchor within stage
```

### 7b. Scope Views
`Features/Managed/`, `Features/User/`, `Features/Project/`, `Features/Session/`

Each scope has a `*ScopeView.swift` driven by `SessionScopeView` or equivalent.
All read from `SessionProjection` (the resolved/merged state from the pipeline).

---

## 8. Dependency Injection Pattern

```swift
// Production: inject real pipeline
let pipeline = ConfigurationPipeline(scanner: WorkspaceScanner(), bookmarkStore: BookmarkStore())
let vm = TreePipelineViewModel()
vm.bind(to: pipeline)

// Tests: inject stub
let stubPipeline = StubConfigurationPipeline()  // in test target only
let vm = TreePipelineViewModel()
vm.bind(to: stubPipeline)
```

**Mock/stub types live in the test target only** — never in the main app target.

All ViewModels hold `weak var pipeline` to prevent retain cycles.
ViewModels observe via Combine: `pipeline.objectWillChange.sink { [weak self] in … }`.

---

## 9. Data Flow

```
Disk files
   ↓
WorkspaceScanner (Discovery)
   ↓
Parsers → ParseResult<T> (typed value + issues)
   ↓
Resolver inputs assembled
   ↓
Individual Resolvers (Settings, Hook, MCP, Agent, Skill, Instruction)
   ↓
SessionProjectionBuilder.build(from:) → SessionProjection
   ↓
ConfigurationPipeline @Published projection
   ↓
ViewModels (observe via Combine)
   ↓
SwiftUI Views (read-only display)
```

Future (Theme F2 — Intention-Based Editing):
```
User intent ("set X to Y")
   ↓
Scope Recommendation Engine (which file should own this?)
   ↓
Pre-save Resolution Preview (show diff before writing)
   ↓
Atomic write: temp file → fsync → rename
   ↓
Pipeline.run() — refresh full state
```

---

## 10. Test Structure

```
ClaudeConfigManagerTests/
├── Parsers/
│   ├── SettingsParserTests.swift
│   ├── ClaudeJsonParserTests.swift
│   └── …
├── Discovery/
│   ├── WorkspaceScannerTests.swift
│   ├── EtcManagedScanTests.swift    ← /etc/claude-code and rules/*.md discovery
│   └── RootLocatorTests.swift
├── Bookmarks/
│   ├── BookmarkStoreTests.swift
│   └── BookmarkExpansionTests.swift  ← userClaudeJson and etcClaudeCodeRoot bookmarks
└── Fixtures/
    └── <parser>/
        └── <case_name>/
            ├── input/   ← raw file(s) fed to parser
            └── expected/ ← expected ParseResult value
```

Every new parser feature must have fixture-based tests. Do not use mocks for parsers — use real input files.

---

## 11. Coding Standards

- `@MainActor` on all `ObservableObject` state classes
- Parsers never throw — return `ParseResult<T>` with issues
- `JSONValue` for all untyped JSON — never `Any`
- All file writes must be atomic: write to temp → `fsync` → `rename`
- Protocol-based DI; stubs in test target only
- `ScopeColorScheme` is the only source of scope colours
- `TokenEstimator`: UTF-8 byte count ÷ 4

---

## 12. Priority Gap Checklist

These are known gaps between the current codebase and the final vision:

| # | Gap | Theme |
|---|-----|-------|
| 1 | **Dual pipeline files** — stub in project, full impl orphaned | Cleanup |
| 2 | `TreePipelineOverviewStrip` is a placeholder strip, not the Unified Diagram | Z |
| 3 | No intention-based editing (Scope Recommendation Engine, atomic write, rollback) | F2 |
| 4 | No `matchedGeometryEffect` zoom on diagram nodes | Z |
| 5 | No `Canvas`-based pipeline diagram | Z |
| 6 | Settings views are read-only; no inline editing UI | F2 |
| 7 | No OTel / telemetry integration (orphaned files may exist) | Cleanup |
| 8 | `TokenEstimator` exists but context budget stage not fully wired into Tree | — |
| 9 | No managed-scope lock indicators in the UI | F2-7 |
| 10 | ✅ ~~`~/.claude.json` had no bookmark~~ — resolved in packet 30a (bookmark infrastructure added) |
| 11 | ✅ ~~`/etc/claude-code/` was a blind spot~~ — resolved in packet 30a (discovery + bookmark added) |
| 12 | No SwiftUI views yet for the new `userClaudeJson` / `etcClaudeCodeRoot` authorize buttons | 30a follow-up |

---

## 13. Governing Documents

| Document | Purpose |
|----------|---------|
| `Documents/VISION_AND_ROADMAP.md` | Feature themes, roadmap, grand vision |
| `Documents/APP_ARCHITECTURE.md` | This file — technical reference |
| `Documents/CLEANUP_PROMPT.md` | Step-by-step agent prompt to fix dual pipeline and clean up orphans |
| `ClaudeConfigManager.xcodeproj/project.yml` | XcodeGen source of truth for project membership |

---

*Generated for Claude Config Manager — April 2026*

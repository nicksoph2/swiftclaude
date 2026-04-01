# Claude Config Manager — Master Task List
**Generated**: April 1, 2026
**Source**: VISION_AND_ROADMAP.md + APP_ARCHITECTURE.md
**Purpose**: Exhaustive, prioritised list of everything needed to achieve the best Claude admin app ever.

---

## How to read this list

**Priority tiers**: P1 = foundational (blocks everything downstream) · P2 = high value (ships after foundation) · P3 = advanced
**Audiences**: L = Learner · Pr = Practitioner · A = Admin
**Status**: ✅ Done · 🔨 In progress / broken · ⬜ Not started
**Dependency notation**: → means "must complete X before starting Y"

---

## Phase 0 — Critical Infrastructure Repair (Blocker for Everything)

These items must be completed before any resolved configuration data can be trusted. Nothing downstream produces correct output until these are done.

### P1. Pipeline Wiring Fix

**P1-1** `P1 · All · 🔨 Broken`
**Fix `buildResolverInputs()` in `ConfigurationPipeline.swift` — the root cause of all empty resolution views.**

- Open `Infrastructure/Pipeline/ConfigurationPipeline.swift` (541 lines, currently untracked in git)
- In `buildResolverInputs()`, replace every `document: nil` stub with the actual parsed document from the parse step:
  - `SettingsSourceCandidate` — pass the `ParseResult<SettingsDocument>` value
  - Agent candidates — pass the `ParseResult<AgentDocument>` value
  - Skill candidates — pass the `ParseResult<SkillDocument>` value
  - CLAUDE.md candidates — pass the `ParseResult<ClaudeMdDocument>` value
- Fix the `.mcpJson` case: currently creates a `ResolutionSource` and discards it — append the MCP candidates properly
- Add typed document fields to `ParseResultRecord` if needed to carry strongly-typed parsed documents alongside `rawContent`/`rawTextContent`
- Delete the stub at `Infrastructure/ConfigurationPipeline.swift` (XcodeRM or bash rm)
- Register the full implementation in `project.yml` under the correct group
- Regenerate the Xcode project with XcodeGen
- Resolve all duplicate type declarations (`PipelineState`, `ConfigFileType`, `ParseResultRecord` defined in both files)
- Fix all 8 compiler warnings — every one is a symptom of the nil-document wiring
- Commit the previously-untracked file to git
- Run full test suite; all 390+ tests must pass

**P1-2** `P1 · All · ⬜`
**Add end-to-end pipeline integration tests.**

- Create fixture directories with real settings, agent, skill, and CLAUDE.md files across multiple scopes
- Write tests that feed fixtures through the full `ConfigurationPipeline.run()` call
- Assert: `resolvePrecedence()` returns non-empty entries with correct values
- Assert: winning scope is correct for each key
- Assert: provenance trace lists all contributing scopes
- Assert: MCP candidates are present in resolution output
- Assert: nil-document regression cannot recur (test that each candidate carries a non-nil document)
- These tests must run as part of the main test scheme

---

## Phase 1 — Foundation (Parser + Managed Tier + Validation)

Must complete before significant UI work begins. Parser completeness determines UI accuracy.

### A. Parser Completeness and Accuracy

**A1** `P1 · All · ⬜`
**Build the Settings Key Registry (schema-driven parsing engine).**

- Create `SettingsKeyRegistry.swift` and `SettingsKeyDefinition.swift` in `Infrastructure/Parsers/`
- Each `SettingsKeyDefinition` carries: key path (dot-notation), expected Swift type, scope restrictions (managed-only / not-at-managed / any), merge hint (override / appendUnique / deepMerge), managed-only flag, deprecation note if applicable
- Implement full registry covering every documented settings key, including nested families:
  - Top-level scalar keys: `model`, `smallModel`, `largeLargeContextModel`, `maxTokens`, `temperature`, `streaming`, `verbose`, `debug`, `outputFormat`, `preferredNotifChannel`, `statusLine`, `showTurnDuration`
  - `permissions` family: `allow[]`, `deny[]`, `ask[]` (all array-merge)
  - `hooks` family: `PreToolUse`, `PostToolUse`, `PreCompact`, `UserPromptSubmit`, `SessionStart`, `SessionEnd`, `Stop`, `SubagentStop`, `Notification` — each with handler array
  - `env` object (key-value pairs)
  - `sandbox` family: `failIfUnavailable`, `allowUnsandboxedCommands`, `network.allowedDomains[]`, `network.httpProxyPort`, `network.socksProxyPort`, `enableWeakerNetworkIsolation`
  - `worktree` family: all documented sub-keys
  - `fileSuggestion` family
  - `plansDirectory`
  - `attribution` object: `commit`, `pr` (replaces deprecated `includeCoAuthoredBy`)
  - Plugin marketplace structures
- Unknown keys continue to emit `.unknownKey(key)` info-level issues — never drop them
- Design the registry for easy extension: adding a key is one struct definition, not a code change
- Add registry-lookup unit tests covering each key family

**A2** `P1 · All · ⬜ (depends on A1)`
**Build the Typed Accessor Layer on top of the registry.**

- Create accessor groupings as computed properties or methods on `SettingsDocument` (or a facade):
  - `ModelSettings`: model, smallModel, maxTokens, temperature, streaming
  - `PermissionSettings`: effective allow/deny/ask arrays
  - `HookPolicySettings`: hooks enabled flag, per-event handler lists
  - `MCPPolicySettings`: disabled servers, strict mode
  - `PluginSettings`: marketplace config
  - `SandboxSettings`: all sandbox sub-keys
  - `UISettings`: statusLine, showTurnDuration, outputFormat, verbose
  - `WorktreeSettings`: all worktree sub-keys
  - `MemorySettings`: any memory/storage-related keys
- All existing parser tests must remain green
- Add typed accessor tests for each group

**A3** `P1 · Pr · A · ⬜`
**Fix and expand the Hook Parser.**

- Correct `timeout`: change from milliseconds to seconds (official spec)
- Add `once` boolean property (skills-only hooks)
- Add `shell` property: `"bash"` or `"powershell"`
- Add handler types `http`, `prompt`, `agent` alongside existing `command`
  - `http`: fields for `url`, `method`, `headers`, `body`
  - `prompt`: fields for `template`, `model`
  - `agent`: fields for `agent_id`, `inputs`
- Update fixture files and all hook parser tests
- Run full test suite

**A4** `P2 · Pr · ⬜`
**Update Attribution parsing.**

- Parse `attribution` as an object with `commit` and `pr` string sub-keys
- Keep `includeCoAuthoredBy` parseable for backward compatibility, marked deprecated
- Emit a deprecation info issue when `includeCoAuthoredBy` is found
- Update UI display (once resolution is live) to show both forms

**A5** `P1 · Pr · ⬜`
**Expand `~/.claude.json` (ClaudeJson) Parser.**

- Add parsing for all currently missing keys:
  - `teammateMode` (boolean)
  - `autoConnectIde` (boolean)
  - `autoInstallIdeExtension` (boolean)
  - `editorMode` (string enum)
  - `showTurnDuration` (boolean)
  - `terminalProgressBarEnabled` (boolean)
  - Any other documented but currently absent keys
- Add fixture cases and unit tests for each new key

**A6** `P1 · A · ⬜`
**First-class parsing of the Sandbox Settings family.**

- Parse the full `sandbox` nested object (defined in A1 above)
- Validate values: `allowedDomains` must be valid hostnames; proxy ports must be integers in valid range
- Emit security-relevant parse issues prominently (`.sandboxNetworkExposed`, `.sandboxDisabled` etc.)
- Add fixture tests for all sandbox keys and validation error paths

### B. Managed Settings Tier

**B1** `P1 · A · ⬜`
**Implement Managed File Discovery.**

- Discover `/Library/Application Support/ClaudeCode/managed-settings.json`
- Discover `/Library/Application Support/ClaudeCode/managed-settings.d/*.json` — merge lexicographically
- Discover `/Library/Application Support/ClaudeCode/managed-mcp.json`
- Discover `/Library/Application Support/ClaudeCode/CLAUDE.md`
- Missing paths → silent (normal absence); inaccessible paths → `DiscoveryIssue` with `.inaccessible` severity
- Handle App Store sandbox restrictions gracefully (catch entitlement errors, surface as info issues)
- Integrate into `WorkspaceScanner` and add to `ScanResult`
- Add `WorkspaceScannerTests` fixtures for managed discovery paths

**B2** `P2 · A · ⬜`
**MDM/Plist reading.**

- Read managed settings from `com.anthropic.claudecode` preference domain via `CFPreferences`
- Normalize plist `NSNumber`, `NSString`, `NSArray`, `NSDictionary` values to `JSONValue`
- Feed through the same `SettingsParser` + registry validation pathway as file-based managed settings
- Keep strictly read-only — no write path for MDM settings
- Document the entitlement requirement for reading system preference domains

**B3** `P1 · A · ⬜ (depends on B1)`
**Managed Tier Resolution with Correct Precedence.**

- Implement the "first tier wins" gate: server-managed > MDM > file-based
- Within file-based managed: merge `managed-settings.d/*.json` files lexicographically
- Register the managed resolver as the absolute highest-precedence tier in `SettingsResolver`
- All existing resolver tests must remain green
- Add resolver tests asserting managed values beat user/project values

**B4** `P2 · A · ⬜ (depends on B3)`
**Full Managed Scope UI.**

- Replace the current managed placeholder view with a real `ManagedScopeView`
- Show: active managed tier (server / MDM / file-based), source path or domain, all enforced policies
- For every managed-controlled setting: show the lock indicator (see F2-5)
- Visually distinguish the three managed sub-tiers with badge labels
- Add "first tier wins" explanation callout at the top of the view

### M. Validation Engine

**M1** `P1 · All · ⬜ (depends on A1)`
**Schema Validation Engine.**

- Implement `SettingsValidator` that takes a parsed `SettingsDocument` and runs every key against the registry
- Emit typed issues: `.invalidFieldType(key, expected, got)`, `.invalidEnumValue(key, value, validValues)`, `.scopeRestrictionViolated(key, scope)`, `.mutuallyExclusiveKeys(key1, key2)`
- Surface schema issues through the existing `ParseResult.issues` pathway — no new issue type needed
- Wire schema validation into each parser so issues appear at parse time
- All existing parser tests must remain green (they should already emit no schema issues on valid fixtures)
- Add schema-validation-specific tests for each error code

**M2** `P2 · Pr · A · ⬜ (depends on M1)`
**Semantic Validation.**

- Detect: deny rules that shadow allow rules at the same or lower scope
- Detect: CLAUDE.md total tokens exceeding 25% of the model context window
- Detect: MCP servers referenced in hooks that are not configured
- Detect: sandbox settings that would block commands required by configured hooks
- Detect: redundant/duplicate permission rules (exact string match within same scope)
- Detect: `attribution.includeCoAuthoredBy` still present alongside new `attribution` object
- Each semantic issue carries a plain-English explanation and a suggestion

**M3** `P2 · All · ⬜ (depends on M1, M2)`
**Validation Issue Aggregation View.**

- Implement a dedicated Issues panel (accessible from both Pipeline tab and Session view)
- Group issues by severity: Error → Warning → Info
- Each issue shows: severity badge, issue code, human-readable message, source file path, pipeline stage
- Each issue is tappable → navigates to the relevant stage and file
- Sidebar badge showing total error + warning count
- "No issues" empty state when configuration is clean

**M4** `P2 · Pr · ⬜ (depends on M1, F2-4)`
**Pre-Edit Validation Preview.**

- Before any edit write, run full schema + semantic validation with the proposed change applied in memory
- Block the save button if the change introduces errors; show specific error messages
- Allow saves that introduce warnings with an explicit "Save anyway" confirmation
- Present validation results in the pre-save diff panel (see F2-3)

---

## Phase 2 — The Unified Interactive Diagram (Theme Z)

Can begin in parallel with Phase 1 — the static layout does not depend on parser completeness. Wire real data in once Phase 1 lands.

**Z1** `P1 · All · ⬜`
**Top-Level Pipeline Overview Diagram — static layout.**

- Replace `TreePipelineOverviewStrip` with a `Canvas`-backed or custom `Layout` view
- Render all eight pipeline stages as connected node cards in a single non-scrolling layout:
  - Discovery → Parsing → Resolution → Prompt Assembly → Tool Execution → Hooks Lifecycle → MCP Servers → Context Budget
  - Target: all 8 visible without scrolling on a 13" MacBook
- Each node card shows: stage name (SF Symbol + label), health indicator (green/amber/red dot), key metric (file count / issue count / token count / server count), scope contribution dots (one per active scope, colored by `ScopeColorScheme`)
- Nodes are connected by directional arrows
- All node positions computed from a fixed layout model (not Auto Layout)
- Build with mock/stub data first; wire to real `SessionProjection` data once pipeline is repaired

**Z2** `P1 · All · ⬜ (depends on Z1)`
**Animated Node Zoom with `matchedGeometryEffect`.**

- Tapping a stage node animates it expanding to fill the detail area
- Remaining nodes compress into a compact breadcrumb navigation strip pinned to the top of the content area
- Back gesture or breadcrumb tap reverses the animation
- All eight existing stage detail views become the zoom-in destinations — internal views unchanged
- Use `matchedGeometryEffect` with a namespace scoped to the diagram view
- Test animation on all 8 stage transitions

**Z3** `P2 · L · Pr · ⬜ (depends on Z2)`
**Navigable Cross-Stage Arrows.**

- Each connecting arrow between stage nodes is tappable
- Tapping opens a "flow panel" (popover or sheet) explaining what travels between those stages:
  - Discovery → Parsing: "These are the raw files that were found and passed to parsers"
  - Parsing → Resolution: "These are the parsed key-value pairs from each file"
  - Resolution → Prompt Assembly: "These are the resolved settings that influence how your prompt is assembled"
  - And so on for each edge
- Each item in the flow panel is itself tappable, linking to its source node within the adjacent stage detail view
- Flow panel content is partly static (explanation text) and partly dynamic (counts and file names from real data)

**Z4** `P2 · Pr · A · ⬜ (depends on Z1, M1)`
**Health Propagation Along Edges.**

- A validation error in any stage propagates a warning indicator along all downstream arrows
- Colour-code propagated warnings (orange for warning-origin, red for error-origin)
- Tapping a propagated warning indicator traces backward to the source stage node
- From the source stage, one more tap navigates to the specific file or key that caused it
- Health state is recomputed whenever the pipeline runs

**Z5** `P2 · L · ⬜ (depends on Z2)`
**Sub-Process Expansion Within Stage Nodes.**

- Within zoomed Resolution view: "Show sub-processes" toggle renders the three merge method paths as parallel lanes with settings flowing down each lane
- Within zoomed Prompt Assembly view: "Show sub-processes" toggle renders the 6 layers stacking sequentially with token budgets
- Toggle state persists in `@SceneStorage`
- Animations use standard SwiftUI transitions (not `matchedGeometryEffect` — this is within a single stage)

**Z6** `P2 · L · ⬜ (depends on Z1, Z2)`
**Simplified 3-Stage Overview Mode.**

- A toolbar toggle collapses the 8-stage diagram into 3 composite nodes:
  - "Your Files" = Discovery + Parsing
  - "The Rules" = Resolution + Permissions
  - "What Claude Sees" = Prompt Assembly + Context Budget + MCP
- Each composite node still zooms in to reveal its constituent stages before drilling to detail
- Default for new users (checked against `AppStorage("hasSeenFullDiagram")`)
- Advanced mode is persistent once activated
- Animate the transition between 3-node and 8-node layouts

---

## Phase 3 — Intention-Based Editing (Theme F2)

Begin after Phase 1 resolution data is correct and the read-only UI is trustworthy.

**F2-4** `P1 · All · ⬜ (depends on P1-1)`
**Atomic Write Infrastructure — build this first, everything else depends on it.**

- Implement `AtomicFileWriter.swift` in `Infrastructure/`
- Write sequence: parse target into memory (or create empty `{}`) → apply change → validate → serialize to canonical JSON (sorted keys, 2-space indent) → write to temp file in same directory → `fsync` → `rename` into place
- On rename failure: leave original untouched, throw error with file path and system error description
- Post-write: re-run full pipeline; if resolved state does not reflect the change, roll back (rename temp back) and surface failure
- Implement `FileBackupStore` that retains the previous version until post-write validation passes
- Unit test: write succeeds → file contains new value → original is gone
- Unit test: write fails at rename → original is untouched
- Unit test: post-write validation fails → rolled back to original

**F2-1** `P1 · Pr · A · ⬜ (depends on F2-4, A1)`
**Edit Mode Toggle and Resolved Settings Editor.**

- Add "Edit" toolbar button to the resolved settings view; toggles `EditMode` state
- In Edit Mode: every setting row gains an inline edit affordance (pencil icon or tap-to-edit)
- Lock icon replaces affordance for any setting locked by managed policy
- Tapping an editable setting opens the scoped editor popover anchored to that row:
  - Shows: current value, current source scope and file, new value input field (type-appropriate: text, picker, toggle, stepper)
  - "Save to:" scope picker (see F2-2)
  - "Why recommended?" one-sentence rationale
  - "Preview Impact" button (see F2-3)
  - "Save" and "Cancel" buttons
- Exiting Edit Mode (Save all / Cancel) returns to read-only view
- Unsaved changes should warn before dismissal

**F2-2** `P1 · Pr · ⬜ (depends on A1, F2-1)`
**Scope Recommendation Engine.**

- For each setting being edited, compute recommended save scope:
  1. If already defined at a writable scope → recommend that scope (update in place)
  2. If not defined anywhere → use setting's category from the registry:
     - Personal preference keys (model, verbose, UI) → user scope
     - Project behaviour keys (hooks, permissions, MCP) → project scope
  3. If defined at a higher-precedence uneditable scope (managed/MDM) → recommend nothing; show lock (see F2-5)
- Rationale text per recommendation: one sentence in plain English ("This setting affects all sessions in this project. Saving here shares it with your team.")
- The user can always override the recommendation to any writable scope
- Implement as `ScopeRecommendationEngine.swift` with protocol for testability; test all three cases above

**F2-3** `P1 · Pr · ⬜ (depends on F2-2, P1-1)`
**Pre-Save Resolution Preview (diff view).**

- "Preview Impact" button in the editor popover triggers an in-memory pipeline run with the proposed change applied
- Present a structured diff panel:
  - New effective value for this key (with before/after comparison)
  - List of any other keys whose resolved values would change as a side effect
  - Updated waterfall view for this key (showing new winning scope)
  - Preview of the exact JSON that would be written to the target file (syntax-highlighted, non-editable)
- Nothing is written to disk at this point
- "Confirm and Save" in the diff panel triggers the atomic write (F2-4)
- "Cancel" discards the preview and returns to the editor popover

**F2-5** `P1 · A · ⬜ (depends on B3)`
**Managed Lock Indicators.**

- In both read-only and Edit Mode views, settings locked by managed policy show a lock icon (SF Symbol `lock.fill`) in the row
- Tapping the lock opens a popover:
  - Which managed tier controls this setting: "Server-managed policy" / "MDM (Mobile Device Management)" / "Managed file"
  - Source: the file path or MDM domain
  - The value it enforces
  - "Contact your administrator to change this setting."
- No edit affordance is shown, ever, for managed-locked settings

**F2-6** `P2 · Pr · ⬜ (depends on F2-2, F2-3)`
**Override Conflict Warning.**

- If the user selects a scope for saving that would be immediately overridden by a higher-precedence scope already defining the same key, surface a prominent warning before "Confirm and Save" becomes active:
  - "This change will have no effect. [Managed scope / User scope] already sets [key] to [value] and takes precedence here."
- Offer two resolution paths: "Change target scope" (returns to scope picker) or "Proceed anyway" (requires explicit confirmation)

**F2-7** `P2 · L · ⬜ (depends on F2-1)`
**Simplified Scope Picker.**

- By default, show the scope picker in simplified form: "This project only" (→ project scope) and "All my projects" (→ user scope)
- "Show advanced options" expands the full six-scope picker
- `AppStorage("useSimplifiedScopePicker")` persists the preference once the user switches to advanced
- Simplified labels should never use the words "scope", "managed", or "resolution"

---

## Phase 4 — High-Value Read-Only UI

**N2** `P1 · All · ⬜`
**Scope Colour Coding — apply consistently everywhere. Highest-leverage visual change.**

- Audit every view in the app; everywhere scope is referenced, apply `ScopeColorScheme.color(for:)` consistently
- Apply scope colours to: resolution waterfall tiers, instruction layer badges, MCP server scope badges, Discovery tree scope indicators, permission rule scope labels, scope contribution dots in the diagram, conflict waterfall cells
- `ScopeColorScheme` is already the single source of truth — the task is ensuring all views actually use it
- Add a visual regression checklist: screenshot each view before and after; confirm no hardcoded colours remain

**C1** `P1 · All · ⬜ (depends on P1-1)`
**Resolution Trace Drill-Down — single most impactful user-facing feature.**

- Tapping any resolved value anywhere in the app opens a `ResolutionTracePanel`
- Panel shows:
  - Effective (winning) value prominently at the top with its scope badge
  - Vertical timeline of every scope that had an opinion, ordered by precedence (Managed → CLI)
  - Per-scope row: scope badge, value declared, participation kind (winning / overridden / merged / absent), greyed-out strikethrough on losers
  - Merge rule applied, in plain English (see C2)
  - For array settings: a merge diagram showing which scope contributed which entries, colour-coded
- Panel is presented as a sheet on narrow windows, popover on wide windows
- "Go to source" button on the winning row navigates to the source file in the Discovery tree

**C2** `P1 · L · ⬜`
**Human-Readable Merge Labels.**

- Replace all developer-internal merge identifiers throughout the UI:
  - `selectHighestPrecedence` → "Overrides — highest scope wins"
  - `appendUnique` → "Merges — all scopes combined"
  - `deepMergeObject` → "Deep merges — per-key precedence"
- Show developer label on hover (tooltip) or in expanded detail only
- Add a small icon per merge type: single chevron (override), double chevron merge (merge), layered squares (deep merge)
- Apply consistently in the resolution waterfall, the trace panel, and any merge method badges

**C3** `P2 · Pr · ⬜ (depends on C1)`
**Conflict Highlighting and Filter.**

- Badge any setting row where multiple scopes disagreed with a small "Resolved conflict" indicator (e.g., `!` in a scope-coloured circle)
- Add a "Conflicts only" filter toggle to the settings list toolbar
- In the trace drill-down panel, show competing values side by side with strikethrough on losers
- In the resolution stage overview, show a conflict count in the stage health summary

**C4** `P2 · Pr · ⬜ (depends on P1-1)`
**Scope Contribution Summaries.**

- Each scope's detail view shows three panels:
  - "Settings this scope wins" — values where this scope is authoritative
  - "Settings this scope contributes to" — array/object merges where this scope contributed entries
  - "Settings this scope loses" — values declared but overridden by a higher scope
- Derived entirely from existing `SessionProjection` data — no new resolution logic needed
- Tapping any row in these panels opens the Resolution Trace for that setting

**H1** `P1 · All · ⬜ (depends on P1-1)`
**Configuration Overview Dashboard — default launch view.**

- Replace the current cold-launch state with a dashboard as the default view
- Dashboard shows:
  - Health summary card: active scope count, total resolved settings, warning count, error count
  - Compact scope stack mini-visualization (Managed → Session, left to right, showing file count per scope)
  - Recent conflicts section: the 3-5 most interesting resolved disagreements (highest scope count, or warnings)
  - File discovery summary: X files found across Y scopes, any missing/inaccessible files
  - Quick-link cards to: Permissions, MCP Servers, Hooks, and the Issues view
- Refreshes automatically when pipeline runs

---

## Phase 5 — Teaching Features (Theme D, I, J)

Can run in parallel with high-value UI once the foundation is stable.

**D1** `P1 · L · ⬜`
**Stage Explanations and Contextual Help.**

- Each of the eight pipeline stages has a persistent explanation panel (collapsible `DisclosureGroup`)
- Content for each stage is a paragraph (not a list) explaining: what Claude Code does at this stage, why it matters, what can go wrong, and how to influence it
- Panels are expanded by default for new users (`AppStorage` tracks dismissal per stage)
- "Re-read explanations" menu item resets all dismissal state
- Write all eight explanations (content work, not just engineering)

**D5** `P2 · L · ⬜ (depends on P1-1)`
**Instruction Load Order Annotation.**

- In the Prompt Assembly stage, annotate each CLAUDE.md layer with:
  - Load order index (1, 2, 3...) displayed as a numbered badge
  - A plain-English callout for the last-loaded file: "This file was loaded last and has the strongest influence on Claude's behavior in this session."
- Explain in a tooltip/annotation: "Files loaded later can override instructions from files loaded earlier. Your project CLAUDE.md is loaded after your user-level CLAUDE.md."

**D4** `P2 · L · ⬜`
**Merge Method Illustrated Examples.**

- When a user first encounters a merge method badge, offer an expandable "Show example" link
- Each example renders a small static before/after diagram:
  - Two scopes declaring different values → the merge rule applied → the effective result
- Three illustrations needed: override, appendUnique, deep merge
- Diagrams are static SwiftUI views — not computed from real data

**D6** `P2 · L · ⬜`
**Permission Evaluation Illustrated Example.**

- In the Tool Execution stage, add a static illustrative example below the real permission gates
- Shows the deny → ask → allow evaluation sequence with a specific hypothetical tool invocation
- E.g.: "If Claude tries to run `bash: rm -rf /tmp/test`, it would check: 1. Deny rules — no match. 2. Ask rules — matches `bash:*`. Result: Claude asks for permission."
- This teaches the evaluation order concretely, independently of the "What If" inspector

**D2** `P2 · L · ⬜ (superseded by Z6 if diagram is built first)`
**Simplified 3-Stage View — Overview mode if Z6 is not built.**

- Only implement if Z6 (Simplified 3-Stage Diagram Mode) is not being built; Z6 is the preferred implementation
- If building standalone: toggle in toolbar collapses eight stages to three panels in the existing list layout

**D3** `P3 · L · ⬜`
**Animated Pipeline Introduction.**

- On first launch (and from Help menu → "How Claude Code works"): play a 5–10 second guided animation
- Animation shows: config files appearing on disk → parsed into keys → keys merging across scopes → prompt assembling → agent starting
- Implemented as a SwiftUI `Canvas` animation or a sequence of `withAnimation` state transitions
- Skippable at any point; "Don't show again" option

**I1** `P2 · Pr · L · ⬜ (depends on P1-1)`
**Dedicated Permissions Inspector.**

- Add a Permissions destination in both the Pipeline tab and the Session view sidebar
- View shows:
  - Evaluation order diagram: Deny → Ask → Allow, with "first match wins" label and arrow
  - Effective rules table grouped by action type: File Operations, Shell Commands, MCP Tools
  - Per-rule row: rule pattern, action (deny/ask/allow), scope badge (which scope contributed it), merge note if multiple scopes contributed
- Provenance tooltip on each rule: which scope file owns it

**I2** `P2 · Pr · ⬜ (depends on I1)`
**Permission Inheritance Tree.**

- Visual tree in the Permissions Inspector showing how permission rules accumulate across scopes
- Managed rules at root, user rules in middle, project rules as leaves
- Array merge (`appendUnique`) shown as entries flowing upward and accumulating
- Make it immediately clear which scope "owns" each rule

**I3** `P2 · A · ⬜ (depends on M2)`
**Permission Conflict Detection.**

- Detect: deny rules that shadow allow rules (deny and allow match the same tool invocation)
- Detect: redundant entries (exact duplicate rules within the same scope)
- Detect: rules that match the same tool with different outcomes across scopes
- Present each conflict as a validation warning with the conflicting rules shown side by side and a plain-English explanation

**J1** `P2 · L · Pr · ⬜ (depends on P1-1)`
**Instruction Load Order Tree.**

- Render CLAUDE.md composition as a visual tree in the Prompt Assembly stage:
  - Session root node at the top
  - Scope-level files as branches (managed, user, project)
  - `@import`-ed files as leaves
- Each node shows: file path, scope badge (colored), discovery order index, token count
- Lines between nodes represent `@import` relationships
- Node opacity or colour encodes influence strength (later-loaded = stronger)
- Tapping a node shows a preview popover with the file's content

**J2** `P2 · A · ⬜ (depends on J1)`
**Import Graph Cycle Detection.**

- Detect circular `@import` chains in the instruction graph
- Surface as a parse error with the full cycle path displayed (A → B → C → A)
- Show which file would not be loaded as a result and what content would be missing

**J3** `P2 · Pr · ⬜ (depends on J1, M2)`
**Instruction Token Budget Warning.**

- When total instruction tokens across all CLAUDE.md files exceeds 25% of the model's context window, surface a warning in the Prompt Assembly stage
- Show which files are the largest contributors (bar chart or table, token count + %)
- Suggest strategies for reduction: "Consider using @import selectively or splitting this file"

**J4** `P2 · Pr · ⬜ (depends on J1)`
**Full Instruction Content Preview.**

- Expand any instruction layer in the Prompt Assembly stage to show its full content
- Header row: file path, line count, token count, scope badge
- Full content rendered in a monospace scroll view
- "Copy to clipboard" action
- "Edit this file" shortcut that opens the CLAUDE.md editor (F3, when built)

---

## Phase 6 — Advanced Editing and File Editors (Theme F)

**F1** `P2 · Pr · A · ⬜ (depends on F2-4, A1)`
**Settings Editor for User Scope (`~/.claude/settings.json`).**

- Inline editing of any setting in the User scope settings view
- Schema-driven: knows valid keys, types, and legal values from the registry
- Structured field editing only (no freeform JSON)
- Atomic write with backup (F2-4); validation before save (M1, M4)
- Show per-field validation errors inline if the current file already has issues

**F2-file** `P2 · Pr · ⬜ (depends on F2-4, A1)`
**Settings Editor for Project Scope.**

- Inline editing of `.claude/settings.json` (team-shared) and `.claude/settings.local.json` (personal)
- Clear visual distinction between the two files: different header colour, label "Shared with team" vs "Personal override"
- Same validation and atomic write behavior as F1

**F3** `P2 · Pr · ⬜ (depends on F2-4)`
**CLAUDE.md Editor.**

- Markdown editor for CLAUDE.md files at any scope
- Live token count displayed in the toolbar (updated as user types)
- Preview panel showing where this file appears in the assembled prompt (load order position)
- Word-wrap formatted display; no raw Markdown rendering required in the editor itself
- Atomic save with backup
- Warning when file approaches a size that would consume >10% of context budget

**F4** `P2 · Pr · ⬜ (depends on F2-4)`
**MCP Server Editor.**

- Add, edit, and remove MCP server definitions from `~/.claude.json` (user scope) and `.mcp.json` (project scope)
- Form-based editor with fields:
  - Server ID (string, unique within scope)
  - Transport type: `stdio` or `http` (picker)
  - For stdio: command (text), arguments (array editor), environment variables (key-value list)
  - For http: URL (text with format validation)
- Validate completeness before showing Save: all required fields present
- Atomic write with backup

**F5** `P3 · A · ⬜ (depends on F2-4, A3)`
**Hook Configuration Editor.**

- Add, edit, and remove hook handlers for any lifecycle event
- Form-based editor: event type (picker), handler type (command / http / prompt / agent), timeout in seconds, optional tool name matchers
- Per handler-type sub-form (command: shell command field; http: URL + method + headers; prompt: template field; agent: agent ID)
- Live validation against hook schema

**F6** `P2 · Pr · ⬜ (depends on F2-4, I1)`
**Permission Rule Editor.**

- Add, edit, and remove entries in `permissions.allow`, `permissions.deny`, `permissions.ask` arrays
- Glob pattern syntax validation with immediate feedback
- Show the effective merged rule list alongside the per-scope editor, updating in real time as user types (before saving)
- One-click test: enter a hypothetical tool invocation string and show which rule would match (links to E1)

**F7** `P3 · A · ⬜ (depends on F2-4, A6)`
**Sandbox Configuration Editor.**

- Structured editor for the sandbox settings family
- Fields: allowed domains (array editor with hostname validation), proxy ports (number fields), `failIfUnavailable` (toggle), `allowUnsandboxedCommands` (toggle with warning)
- Clear warnings when settings would restrict tools or expose the network in unintended ways

---

## Phase 7 — The "What If" Inspector (Theme E)

**E1** `P2 · Pr · L · ⬜ (depends on P1-1, I1)`
**Permission Rule Simulator.**

- A panel (accessible from the Permissions Inspector and the Tool Execution stage)
- User types a hypothetical tool invocation: e.g., `bash: rm -rf node_modules` or `mcp__github__create_issue`
- App traces it through the actual configured permission rules and hooks:
  - Deny rules checked first: first match → denied (show which rule, which scope)
  - Ask rules checked: first match → ask (show which rule, which scope)
  - Allow rules checked: first match → allowed (show which rule, which scope)
  - No match → default behavior (show what the default is)
  - Which hooks would fire: PreToolUse, PostToolUse (list handlers)
- No code is executed — pure in-memory rule evaluation
- Result displayed as a step-by-step trace, each step tappable to show the matching rule

**E2** `P2 · Pr · ⬜ (depends on F2-3, P1-1)`
**Settings Change Impact Preview.**

- User selects any scope and key, proposes a new value
- App runs the pipeline in memory with the change applied and shows:
  - New effective value for this key
  - Any other keys whose resolved values would change (dependency effects)
  - Which scopes would now be overridden (scopes that declared a value that no longer wins)
  - Updated waterfall diagram for this key
- No files written — pure preview
- "Apply this change" button routes to the Edit Mode flow (F2-1 → F2-3 → F2-4)

**E3** `P3 · Pr · ⬜ (depends on J1)`
**CLAUDE.md Import Tracer.**

- User proposes adding an `@import path/to/file.md` directive to any CLAUDE.md file
- App shows: where the imported content would appear in the instruction load order, how many additional tokens it would consume, how it would interact with existing instructions
- Presents the resolved instruction stack with the hypothetical import included

**E4** `P3 · Pr · ⬜ (depends on K1)`
**MCP Server Removal Preview.**

- User selects an MCP server and requests a removal preview
- App shows: which tools would disappear from Claude's capability set, the tool count change, a list of removed tools with descriptions
- Useful for evaluating policy changes before applying them

---

## Phase 8 — Dashboard and Navigation (Theme H)

**H2** `P2 · Pr · ⬜ (depends on P1-1)`
**Global Settings Search (⌘F).**

- Persistent search bar in the toolbar, activated by ⌘F
- Searches across: all resolved settings key names and values, all file paths, all MCP server names, all hook event types
- Results show: effective value, winning scope, one-click navigation to the relevant pipeline stage and key
- Results update as user types (debounced 150ms)
- Empty state with suggested searches: "model", "permissions.deny", "mcp"

**H3** `P2 · All · ⬜`
**Scope Stack Sidebar Navigation.**

- Restructure the sidebar from a flat list into a visual Scope Stack:
  - Managed (top, highest precedence)
  - User
  - Project / Project-Local
  - Session / CLI (bottom)
  - Separator
  - Resolved Configuration (output of the stack)
  - Pipeline View
  - Issues
- Each scope layer shows: file count badge, issue badge, active/inactive indicator
- Communicates the precedence hierarchy visually, without requiring the user to learn the terminology

**H4** `P2 · Pr · ⬜`
**Full Keyboard Navigation.**

- Arrow key navigation across the pipeline overview diagram nodes
- Tab / Shift-Tab within stage content views
- Keyboard shortcuts:
  - ⌘1–8: jump to each pipeline stage
  - ⌘R: refresh (re-run pipeline)
  - ⌘E: enter/exit Edit Mode
  - ⌘S: save current edit
  - ⌘F: global search
  - Escape: back / close popover
- VoiceOver-complete: semantic labels on all custom controls

**H5** `P3 · Pr · ⬜`
**Two-Level Session Navigation.**

- Replace the current segment picker in Session view with a two-level sidebar + detail layout:
  - Left: grouped list — Configuration (Settings, Permissions, Instructions, Hooks, MCP, Agents & Skills) and Diagnostics (Transcripts, Usage, Issues)
  - Right: detail area for selected item
- Scales as the feature set grows; organises by user intent rather than data type

---

## Phase 9 — Snapshots and Profiles (Theme G)

**G1** `P2 · A · Pr · ⬜ (depends on P1-1)`
**Configuration Snapshot Export.**

- Export the current fully-resolved configuration state as a structured JSON or YAML document
- Includes: all resolved settings with provenance, resolved instruction stacks (token counts), MCP server landscape (active / blocked / overridden), effective permission rules (merged across scopes), hook lifecycle (all configured handlers)
- Excludes: auth tokens, API keys, sensitive env vars (flag their presence without revealing values)
- File format choice: JSON (default), YAML (opt-in)
- Export via share sheet or save-to-file dialog

**G2** `P3 · A · ⬜ (depends on G1)`
**Named Configuration Profiles.**

- Save the current settings for a specific scope as a named profile (e.g., "Strict Security Mode")
- Profiles store scope-specific settings only, not the full resolved state
- Profile is stored in an app-owned file (not in Claude-owned config files)
- Apply a profile to a scope: shows a change impact preview (E2) before applying
- Profile manager UI: list of profiles, create/rename/delete, preview selected profile

**G3** `P3 · Pr · ⬜ (depends on G1)`
**Configuration Diff View.**

- Compare two snapshots side by side, or compare current resolved state against a saved profile
- Color-coded diff: added settings (green), removed settings (red), changed settings (amber)
- Shows scope of each change
- Useful for auditing configuration changes over time or between environments

**G4** `P3 · A · ⬜ (depends on G2)`
**Profile Sync via iCloud.**

- Optional iCloud sync for named profiles via `NSUbiquitousKeyValueStore` or CloudKit
- Only profiles (app-owned metadata) sync — never Claude-owned config files or auth tokens
- Conflict resolution: last-write-wins with timestamp, no merge

---

## Phase 10 — MCP Server Management (Theme K)

**K1** `P2 · Pr · ⬜ (depends on P1-1)`
**MCP Server Card Redesign.**

- Redesign each MCP server entry as a card with:
  - Server name (title, monospace)
  - Scope badge (coloured pill)
  - Transport type icon: terminal icon for stdio, globe icon for HTTP
  - Validation status: green checkmark (complete) or red warning (missing required fields)
  - "Overridden by" callout when a higher scope shadows this server
  - Collapsible detail section: full config, resolution trace for this server ID
- Apply `ScopeColorScheme` colours to all scope badges

**K2** `P2 · L · Pr · ⬜ (depends on K1)`
**MCP Tool Catalog.**

- For each active MCP server, list every tool it contributes to Claude's capability set
- Each tool entry: tool name, description, input schema summary (parameter names and types), source server badge
- Alongside the built-in tool catalog (18 tools) — show all tools in a unified, searchable list
- Total capability count: "Claude has access to X tools in this configuration"
- Tapping a tool in the Tool Execution stage cross-links to its catalog entry

**K3** `P3 · Pr · ⬜ (depends on K1)`
**MCP Server Override Visualization.**

- When user-scope and project-scope both define a server with the same ID, show the override relationship explicitly:
  - Active definition (winning scope): full card, bright
  - Suppressed definition (losing scope): greyed out card with "Overridden by [winning scope]" label
  - Delta section: what differs between the two definitions
- Currently both are shown without override markup

**K4** `P3 · Pr · ⬜ (depends on K1)`
**MCP Server Health Check.**

- For stdio-based servers: check that the command exists at the specified path and is executable (use `FileManager.fileExists` + `isExecutableFile`)
- For HTTP-based servers: validate URL format (scheme, host, no auth credentials)
- Surface issues as `.mcpCommandNotFound(serverId, path)` or `.mcpInvalidUrl(serverId, url)` errors in the Parsing stage
- Health check runs as part of the pipeline, not on demand

---

## Phase 11 — Session and Runtime (Theme L)

**L2** `P2 · Pr · ⬜`
**Session Transcript Reader.**

- Full-featured transcript viewer for `.jsonl` session files
- Show each turn with: role badge (user/assistant/tool), content text, tool use (name + input), tool result, token usage per turn
- Jump-to-turn: scroll to any turn by index
- Full-text search within transcript (highlights matching turns)
- Export human-readable summary (markdown)
- Handles large `.jsonl` files by streaming (do not load entire file into memory)

**L3** `P2 · Pr · ⬜ (depends on L2)`
**Usage Analytics Dashboard.**

- Aggregate usage data across multiple sessions and projects from local `.jsonl` files
- Metrics: total tokens, total estimated cost (at standard API rates), model distribution over time, most-used tools, session count by project
- Charts: line chart (tokens over time), pie/donut (model distribution), bar chart (top tools)
- Time window filter: last 7 days, 30 days, 90 days, all time
- All computed locally — no network access

**L1** `P3 · Pr · ⬜`
**Live Session Binding.**

- Connect to a currently-running Claude Code instance via its status-line JSON payload or transcript file watcher
- Display in the Context Budget stage: live token consumption (vs. estimated)
- Display in the Tool Execution stage: currently active tool (if any)
- Display in the Hooks Lifecycle stage: currently executing hook (if any)
- Toggle in the toolbar: "Live" / "Estimated" — Live requires an active session

**L4** `P3 · Pr · ⬜ (depends on L2)`
**Subagent Session Visualization.**

- Read subagent session files from `~/.claude/projects/<key>/<session>/subagents/*.jsonl`
- Display the hierarchical parent→subagent relationship as a collapsible tree
- Each node: agent task summary (first user turn), token usage, status (complete/running)
- Show how the parent session consumed the subagent result (which tool_result turn)

---

## Phase 12 — Accessibility and Polish (Theme N)

**N1** `P2 · All · ⬜`
**Full Accessibility Pass.**

- VoiceOver labels (`accessibilityLabel`) on all custom controls:
  - Health badge: "Discovery stage: 2 warnings"
  - Waterfall tier: "User scope: claude-sonnet-4-6, overridden"
  - Scope contribution dot: "Project scope contributing"
  - Pipeline stage node: "Resolution stage, tap to expand"
- Accessibility hints (`accessibilityHint`) on non-obvious interactions:
  - Cross-stage navigation links: "Opens Resolution stage and scrolls to this key"
  - Popover triggers: "Opens file detail popover"
- VoiceOver grouping: related elements (scope badge + value + merge label) grouped as one accessible element with a combined label
- Full keyboard navigation within all views (see H4)
- Test with VoiceOver on before shipping any phase

**N3** `P2 · All · ⬜`
**Responsive Popover Sizing.**

- Audit all popovers; fix sizing for windows narrower than 500pt
- Use adaptive presentation: `.sheet` presentation on narrow windows, `.popover` on wide windows
- Test at: 400pt, 500pt, 800pt, 1200pt window widths
- Applies to: file detail popovers, resolution trace panel, editor popover, permissions inspector

**N5** `P2 · Pr · ⬜`
**Monospace Copy-Paste for All Values.**

- Audit every key path, file path, setting value, tool invocation string, and server name in the app
- Ensure all are selectable and copyable:
  - Add `contextMenu { Button("Copy") { UIPasteboard... } }` to every monospace `Text` view
  - Or use `.textSelection(.enabled)` on text views where supported
- Add a copy icon (clipboard SF Symbol) next to long values
- Test: right-click any key name → "Copy" option appears

**N4** `P3 · Pr · ⬜`
**Card vs Table View Toggle.**

- Toggle in the settings list toolbar between card view (current) and compact table view
- Table view: 1 row per setting, key name + value + scope badge + conflict indicator, dense layout
- `AppStorage("settingsViewStyle")` persists the preference
- Card view remains default

---

## Cross-Cutting Concerns (apply throughout all phases)

**CC1 — Test coverage for every new feature**
- Every parser feature: fixture-based unit test with `input/` and `expected/` directory pair
- Every resolver change: unit tests asserting correct merge output
- Every new view: at minimum, a `@MainActor` preview that compiles and renders
- ViewModel logic: unit tests with stub pipeline injection
- Never break existing tests — run the full suite after every change

**CC2 — Schema extensibility**
- The settings key registry (A1) must be designed to add new keys with zero code changes outside the registry definition file
- When Anthropic adds new settings keys, the process should be: add one `SettingsKeyDefinition` struct → tests update → UI automatically picks it up
- Unknown keys always surface as info-level issues, never silently discarded

**CC3 — Performance**
- Pipeline runs must complete in < 500ms for typical configurations (< 20 config files)
- Transcript streaming (L2) must handle 100k-line `.jsonl` files without hanging the main thread
- All pipeline work on background actors; UI updates via `@MainActor`
- Profile pipeline phases with `os_signpost` to identify bottlenecks before they ship

**CC4 — Provenance is always first-class**
- Every value in the resolved configuration always carries its full provenance chain
- Provenance is always available one interaction deep (tap to see source)
- Never show a value without a way to discover where it came from

**CC5 — Writes are always atomic and validated**
- The atomic write infrastructure (F2-4) is used for every file write, with no exceptions
- No edit reaches disk without schema + semantic validation passing (or explicit user override)
- A failed or rolled-back write always leaves the original file intact

---

## Dependency Order Summary

```
P1-1 (pipeline wiring) ──────────────────────────────────────────────┐
  └─► P1-2 (integration tests)                                        │
                                                                       │
A1 (key registry) ──► A2 (typed accessors) ─────────────────────────►│
A3 (hook parser fix)                                                   │
A5 (claude.json expansion)                                             │
A6 (sandbox parsing)                                                   │
  └─► M1 (schema validation)                                           │
         └─► M2 (semantic validation)                                  │
                └─► M3 (issues aggregation view)                       │
                                                                       ▼
B1 (managed discovery) ─► B3 (managed tier resolution) ──► B4 (managed UI)
  └─► B2 (MDM plist reading)                                           │
                                                                       │
All of above ──────────────────────────────────────────────────────────►
  ├─► C1 (resolution trace drill-down)
  ├─► H1 (dashboard)
  ├─► N2 (scope colour audit)
  ├─► F2-4 (atomic write) ─► F2-1 ─► F2-2 ─► F2-3 ─► F2-5/6/7
  └─► Z1 (diagram) ─► Z2 ─► Z3, Z4, Z5, Z6

Z1 → Z2 can begin with mock data before P1-1 is complete.
```

---

*This document is the master backlog. Update status markers as work completes. Treat it as a living reference alongside the implementation packets in `IMPLEMENTATION_PLAN_V2.md`.*

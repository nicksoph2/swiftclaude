# Claude Config Manager - Project Index

## Product goal
Build a native macOS application that inspects, validates, and edits the real configuration surface used by Claude Code.

The app is not a second source of truth. It reads Claude-owned files on demand, computes the effective state in memory, and writes changes back atomically to the correct files.

## V1 scope
V1 is a read-first, resolver-first release with limited editing after the core is stable.

### Included in V1
- Native macOS app built with Swift and SwiftUI
- Sidebar with four scopes: Managed, User, Project, Session
- Global settings root picker
- Project root picker and project registry
- File discovery for Claude-related files under user and project roots
- Parsing support for:
  - `settings.json`
  - `~/.claude.json`
  - `.mcp.json`
  - `CLAUDE.md`
  - agent markdown files
  - skill `SKILL.md` files
- Deterministic Session resolver for:
  - resolved settings
  - resolved instructions
  - resolved MCP servers
  - visible agents and skills
  - source provenance and validation issues
- Read-only Session UI for inspecting effective state
- Validation engine for syntax, schema, and semantic checks
- Atomic write-through editing for a small set of core file types after the read-only core is stable
- Derived usage summary groundwork only

### Explicit non-goals for initial implementation
- Hidden database or shadow config store
- Billing-grade usage ledger
- Cloud sync layer
- Cross-platform support
- Arbitrary plugin runtime or remote execution shell
- Editing every file type on day one

## Core product rules
- Claude files are authoritative
- No shadow database
- Resolved views are computed, not persisted
- App-owned files contain only reproducible derived state and UI metadata
- Session is always read-only
- Writes must validate, render canonical output, and replace files atomically

## Architecture summary
The app is split into:
- SwiftUI app shell and navigation
- Discovery layer for user root and project roots
- Parsers for each Claude-related file type
- Resolver layer for settings, instructions, MCP, agents, and skills
- Validation engine for syntax, schema, and semantic checks
- Editors and atomic writer for supported file types
- Small app-owned JSON files for project registry and reproducible derived summaries

### Scope model
- Managed
- User
- Project
- Session

### Main file classes
- `~/.claude/settings.json`
- `<project>/.claude/settings.json`
- `<project>/.claude/settings.local.json`
- `~/.claude.json`
- `<project>/.mcp.json`
- `~/.claude/CLAUDE.md`
- `<project>/CLAUDE.md`
- `<project>/.claude/CLAUDE.md`
- auto-memory files under `~/.claude/projects/<project>/memory/`
- agent files under `.claude/agents/`
- skill directories under `.claude/skills/`

## Module map
### App shell
- `ClaudeConfigManagerApp`
- `AppRouter`
- `SidebarState`
- `DocumentSelectionState`

### Discovery and pathing
- `ProjectRegistry`
- `RootLocator`
- `BookmarkStore`
- `WorkspaceScanner`
- `FileWatcher`

### Parsers
- `SettingsParser`
- `ClaudeJsonParser`
- `ClaudeMdParser`
- `McpParser`
- `AgentParser`
- `SkillParser`
- `HookParser`

### Resolver layer
- `ScopeResolver`
- `SettingsResolver`
- `InstructionResolver`
- `HookResolver`
- `MCPResolver`
- `AgentResolver`
- `SkillResolver`
- `SessionProjectionBuilder`

### Validation and save
- `ValidationEngine`
- `SchemaValidator`
- `SemanticValidator`
- `ConflictAnalyzer`
- `AtomicWriter`

### Derived state
- `UsageDeriver`
- `FingerprintStore`

## Milestones
### Milestone 1 - Read-only core
Goal: choose roots, scan files, parse them, resolve Session state, and display results read-only.

Included packets:
- `A1_XCODE_SETUP`
- `A2_APP_SANDBOX_AND_BOOKMARKS`
- `A3_GLOBAL_AND_PROJECT_ROOT_PICKERS`
- `B1_ROOT_LOCATOR`
- `C1_SETTINGS_JSON_PARSER`
- later parser packets for other file types
- resolver packets beginning with `D1_RESOLVER_MODELS`

### Milestone 2 - Editing core
Goal: edit supported files safely, validate before save, preview writes, and use atomic write-through behavior.

### Milestone 3 - Usage and polish
Goal: derived usage summaries, provenance UI, test hardening, and beta preparation.

## Current status
- Product direction is defined
- Planning structure is being created
- No implementation files assumed yet
- Immediate next target is Milestone 1

## Documentation map
### Section docs
- `Docs/Sections/SECTION_A_APP_SHELL.md`
- `Docs/Sections/SECTION_B_DISCOVERY.md`
- `Docs/Sections/SECTION_C_PARSERS.md`
- `Docs/Sections/SECTION_D_RESOLVER.md`

### Packet docs created now
- `Docs/Packets/A1_XCODE_SETUP.md`
- `Docs/Packets/A2_APP_SANDBOX_AND_BOOKMARKS.md`
- `Docs/Packets/A3_GLOBAL_AND_PROJECT_ROOT_PICKERS.md`
- `Docs/Packets/B1_ROOT_LOCATOR.md`
- `Docs/Packets/C1_SETTINGS_JSON_PARSER.md`
- `Docs/Packets/D1_RESOLVER_MODELS.md`

### Handoff doc
- `Docs/AI_DRAFT_OTHERS_HANDOFF.md`

## Working conventions for future AI sessions
- Always load this file first
- Then load one section doc
- Then load one packet doc
- Keep implementation scoped to the selected packet
- End each implementation chat with:
  - files created or updated
  - assumptions made
  - open questions
  - next recommended packet

## Packet quality bar
Every packet should define:
- Goal
- Inputs
- Dependencies
- Deliverables
- Acceptance criteria
- Out of scope
- Done when

## Open decisions to track later
- Canonical JSON formatting rules
- Markdown import graph visualization style
- Exact validation severity taxonomy
- Whether some editors need AppKit-backed text components

# Claude Config Manager - Agent Instructions

## Project Overview

This is a native macOS SwiftUI app that inspects, validates, and displays the full Claude Code configuration surface. The app reads Claude-owned config files, computes the effective resolved state, and displays it read-only with full provenance.

## Architecture

The app has four layers:

- **App shell**: `ClaudeConfigManagerApp`, `AppRouter`, `RootSplitView`, sidebar navigation
- **Discovery**: `RootLocator`, `WorkspaceScanner`, `BookmarkStore` — finds config files on disk
- **Parsers**: `SettingsParser`, `ClaudeJsonParser`, `AgentParser`, `SkillParser`, `ClaudeMdParser` — parse each file type into typed Swift models
- **Resolver + UI**: Merges parsed data across scopes (Managed > User > Project > Session), validates, and presents in `SessionScopeView`

Key source paths:
- `ClaudeConfigManager/App/` — app entry, router, sidebar
- `ClaudeConfigManager/Core/Models/` — shared model types
- `ClaudeConfigManager/Features/` — per-scope SwiftUI views (Managed, User, Project, Session)
- `ClaudeConfigManager/Infrastructure/Parsers/` — all parsers
- `ClaudeConfigManager/Infrastructure/Discovery/` — file discovery and root resolution
- `ClaudeConfigManager/Infrastructure/Bookmarks/` — macOS security-scoped bookmark management
- `ClaudeConfigManager/Infrastructure/Resolver/` — resolution models and merge logic

Test paths:
- `ClaudeConfigManagerTests/Parsers/` — parser unit tests with fixture data
- `ClaudeConfigManagerTests/Discovery/` — scanner and locator tests
- `ClaudeConfigManagerTests/Bookmarks/` — bookmark store tests
- `ClaudeConfigManagerTests/Fixtures/` — test fixture files (JSON, markdown, etc.)

## Build and Test

```bash
# Build
xcodebuild build -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager -destination 'platform=macOS' -quiet

# Test
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager -destination 'platform=macOS' -quiet

# Build and test together
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager -destination 'platform=macOS' -quiet 2>&1 | tail -20
```

## Coding Standards

- Swift 5.9+, targeting macOS 14+
- Use SwiftUI for all views
- Use `@MainActor` for observable state classes
- Parsers return `ParseResult<T>` with typed value + issues array
- All parsers preserve unknown fields in raw form for forward compatibility
- Use protocol-based dependency injection for testability
- Mock types go in the test target, not the main target
- Test fixtures use the directory structure: `Fixtures/<parser>/<case_name>/input/` and `expected/`

## Implementation Packet Conventions

When implementing a packet from `Documents/IMPLEMENTATION_PLAN_V2.md`:

1. **Start** by reading `Documents/PROJECT_INDEX.md` for overall context
2. **Read** the specific packet description in the plan
3. **Check** for handoff docs from previous packets: `Documents/<PACKET_ID>-handoff.md`
4. **Read** the existing source files you'll modify before making changes
5. **Implement** the deliverables, following existing patterns
6. **Write tests** for all new functionality using the fixture pattern
7. **Run tests** and fix failures until all pass
8. **Create a handoff doc** at `Documents/<PACKET_ID>-handoff.md` with:
   - Files created or modified (list each)
   - Key decisions and assumptions made
   - Any issues encountered or open questions
   - Recommended next packet

## Critical Rules

- NEVER break existing tests. Run the full test suite after changes.
- NEVER modify the Xcode project file structure manually — add files through the file system and let Xcode folder references pick them up.
- NEVER remove or rename existing public API without backward compatibility.
- If you encounter a blocker requiring human input, write it to `Documents/<PACKET_ID>-BLOCKED.md` and stop working.
- Keep each packet scoped — do not implement work belonging to other packets.
- When adding new settings.json keys, use the schema-driven registry approach (after G1/G2 are implemented).
- Use `JSONValue` for untyped/flexible data, not `Any`.
- Parser issue codes should be descriptive: `.invalidFieldType(key, expected, got)` not just `.invalidField`.

## File Naming

- New Swift files follow existing naming: `<Purpose><Layer>.swift` (e.g., `ManagedSettingsLocator.swift`)
- Test files: `<TestedType>Tests.swift`
- Fixtures: `Fixtures/<parser>/<case_id>/input/<filename>` and `expected/<filename>`
- Handoff docs: `Documents/<PACKET_ID>-handoff.md`

# Implement Packet G1: Settings Key Registry and Schema-Driven Parsing

Work in this repository:

- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp`

Your task is to implement **Packet G1** from the planning docs. This is a coding task, not a planning-only task. Read the authoritative documents first, then inspect the current source, implement the packet end-to-end, add tests/fixtures, run the relevant test/build commands, and finish with a short handoff doc.

## Authoritative docs to load first

Before making changes, load and follow these documents first:

1. `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/AGENT_FRAMEWORK.md`
2. `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/Specs/01-G1-settings-key-registry.md`
3. `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/CLAUDE.md`

For this packet, if wording overlaps across docs, treat the packet spec as the most specific source of truth and treat the framework + `CLAUDE.md` as process/conventions guidance.

## Context docs to consult after that

Use these for orientation and module/dependency context, but do not let them override the packet spec:

1. `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
2. `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/IMPLEMENTATION_PLAN_V2.md`
3. Any existing handoff/blocker docs for this packet if present:
   - `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/G1-handoff.md`
   - `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/G1-BLOCKED.md`

## Current source and tests to inspect before editing

Then inspect these implementation files before editing:

- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/ClaudeConfigManager/Infrastructure/Parsers/SettingsParser.swift`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/ClaudeConfigManagerTests/Parsers/SettingsParserTests.swift`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/ClaudeConfigManagerTests/Fixtures/parsers/settings/valid_basic/input/settings.json`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/ClaudeConfigManagerTests/Fixtures/parsers/settings/valid_basic/expected/summary.json`

Optionally inspect this fixture note if you need fixture-layout context:

- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/ClaudeConfigManagerTests/Fixtures/parsers/settings/README.md`

If other parser/model files are needed after inspection, read them too, but keep the work scoped to G1.

## Project context you must respect

- This app is a native macOS SwiftUI app that inspects, validates, and edits the real Claude Code configuration surface.
- Claude-owned files are authoritative.
- Do not introduce a shadow config store or persisted resolved state.
- Session data remains computed/read-only.
- Keep provenance/diagnostics first-class.
- Parsers must preserve unsupported keys when possible.
- Use `JSONValue` for flexible/untyped data, never `Any` in new parser-facing structures.
- Do not manually edit Xcode project structure.
- Do not remove or rename public API without backward compatibility.
- Keep the packet scoped. Do not implement G2 or later resolver/validation/UI packets except for minimal compatibility shims explicitly required by G1.

## General parser and test rules

Follow the existing parser architecture:

- Parsers return `ParseResult<T>` with typed `value` and `issues`
- Unknown keys should remain preserved for forward compatibility
- Issue severity should match current conventions:
  - `info` for preserved unsupported keys
  - `warning` for known keys with wrong types
  - `error` for structural problems
- Tests and fixtures are required for new behavior
- Keep existing tests passing

Use the existing fixture layout:

- `ClaudeConfigManagerTests/Fixtures/<family>/<case_id>/input/...`
- `ClaudeConfigManagerTests/Fixtures/<family>/<case_id>/expected/...`

## Packet G1 goal

Replace the bespoke top-level-property parsing approach in `SettingsParser` with a **schema-driven registry** that can scale to the current Claude Code settings surface, while preserving current parser behavior and compatibility.

This packet is the foundation for later packets. The registry becomes the authoritative local description of known settings keys, their shapes, category grouping, scope applicability, managed-only constraints, and future merge hints.

## Required deliverables

Implement the following:

### 1. Create a settings key registry

Create:

- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/ClaudeConfigManager/Infrastructure/Parsers/SettingsKeyRegistry.swift`

It must define at minimum:

- `SettingsKeyType`
- `SettingsKeyCategory`
- `SettingsKeyDefinition`
- `SettingsKeyRegistry`

The registry should cover the currently verified settings families:

- general
- environment and helpers
- attribution and git behavior
- model and reasoning
- permissions
- hooks and hook policy
- MCP controls
- sandbox
- plugins and marketplaces
- authentication and identity helpers
- memory and CLAUDE.md behavior
- UI and session experience
- worktree
- updates and misc operational settings

### 2. Registry semantics

Each key definition should include:

- canonical key path
- expected value shape
- category
- description
- managed-only flag when applicable
- applicable scopes
- merge hint for later resolver work

Nested families such as these must be representable without flattening away structure too early:

- `sandbox`
- `permissions`
- `statusLine`
- `fileSuggestion`
- `worktree`
- marketplace source objects

### 3. Update `SettingsParser`

Update `SettingsParser.parse()` so that:

- known keys are validated against the registry
- unknown keys still produce preserved-key info issues
- known keys with type mismatches produce warning-level issues
- existing named-property parsing remains unchanged for now

Do not break:

- `ParseResult<ParsedSettingsDocument>`
- current parser helper signatures unless there is a very strong reason
- current parser tests

### 4. Add advanced read-only registry entries

Register the following keys with an `advanced` or equivalent metadata flag:

- `pluginConfigs`
- `skippedPlugins`
- `skippedMarketplaces`

These are:

- parseable
- preservable
- displayable later as advanced/internal
- intentionally read-only diagnostic data

They are **not** verification-gated or ignored.

## Important corrections that must be reflected in G1

Your registry coverage must reflect the corrected planning docs, including:

- include currently documented settings such as:
  - `alwaysThinkingEnabled`
  - `allowedChannelPlugins`
  - `channelsEnabled`
  - `defaultShell`
- promote these to first-class registry entries:
  - `autoMemoryEnabled`
  - `claudeMdExcludes`
- treat these as advanced read-only registry entries:
  - `pluginConfigs`
  - `skippedPlugins`
  - `skippedMarketplaces`
- `strictKnownMarketplaces` is **not** a boolean
- `allowedMcpServers` and `deniedMcpServers` are structured rule arrays, not plain string arrays
- sandbox is a nested object family, not a bag of flat keys

## Current code realities you must preserve

The existing parser currently has:

- `ParseResult`
- `SyntaxIssue`
- `JSONValue`
- `ParsedSettingsDocument`
- `SettingsDocumentValue`
- helper parsing methods
- settings parser tests that validate current named fields and unknown-key preservation

G1 must preserve current behavior for the already-supported fields while laying the registry foundation underneath it.

If you introduce a registry-backed generic storage model for `SettingsDocumentValue`, keep compatibility shims so existing tests and current named-property consumers do not break.

## Suggested source files to touch

You will likely need to modify:

- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/ClaudeConfigManager/Infrastructure/Parsers/SettingsParser.swift`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/ClaudeConfigManager/Infrastructure/Parsers/SettingsKeyRegistry.swift`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/ClaudeConfigManagerTests/Parsers/SettingsParserTests.swift`

You will likely need to add fixture cases under:

- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/ClaudeConfigManagerTests/Fixtures/parsers/settings/`

Possible new fixture cases:

- valid registry-covered modern keys
- known key wrong type -> warning
- advanced read-only keys preserved/registered
- nested family shape coverage
- unknown key preservation unchanged

## Implementation guidance

- Start by modeling the registry types cleanly and keeping them independent of resolver logic.
- Add a clear way to check whether a top-level or nested key path is known and what shape is expected.
- Prefer incremental integration: validate current parsed keys against the registry first, then expand preserved-known coverage where helpful.
- Preserve current named-property parsing semantics for already-supported fields.
- Do not try to fully solve typed accessor ergonomics in this packet; that belongs to G2.
- If the current source differs from the docs, adapt to the real codebase and document the difference in the handoff.

## Required verification

Run the relevant tests after implementation. At minimum run:

```bash
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager -destination 'platform=macOS' -quiet
```

If you need a faster intermediate pass first, you may also run targeted tests, but do not finish without running the full suite expected by the project docs.

## Acceptance criteria

Do not stop until these are satisfied:

- existing supported keys parse exactly as before
- unknown keys remain preserved and reported
- known keys with wrong types emit warning-level issues
- registry coverage reflects the current verified settings surface rather than the older local estimate
- `autoMemoryEnabled` and `claudeMdExcludes` are first-class registry entries
- `pluginConfigs`, `skippedPlugins`, `skippedMarketplaces` are registered as advanced read-only
- the registry structure is ready for G2 typed accessors and later resolver/validation work
- current parser tests still pass
- new tests/fixtures cover the registry-backed behavior you added

## Required final outputs

When finished:

1. Provide a short summary of what changed
2. List every file created or modified
3. State any assumptions made
4. State any open questions or follow-up risks
5. Recommend the next packet
6. Create a handoff doc at:
   - `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/G1-handoff.md`

If you hit a real blocker requiring human input, stop and create:

- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/G1-BLOCKED.md`

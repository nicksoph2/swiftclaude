# Packet G1: Settings Key Registry and Schema-Driven Parsing

## Overview

This packet replaces the bespoke top-level-property parsing approach in `SettingsParser` with a schema-driven registry that can scale to the current Claude Code settings surface. The registry becomes the authoritative local description of known settings keys, their shapes, category grouping, scope applicability, and managed-only constraints.

The implementation must preserve backward compatibility for the fields the app already parses today while making it cheap to add modern settings families such as sandbox, hook policy, MCP policy, plugin marketplace policy, worktree, memory, and Session UX settings.

## Important corrections

- Include currently documented settings such as `alwaysThinkingEnabled`, `allowedChannelPlugins`, `channelsEnabled`, and `defaultShell`
- Promote `autoMemoryEnabled` and `claudeMdExcludes` to first-class registry entries (they appear in current schema and documentation). Treat `pluginConfigs`, `skippedPlugins`, and `skippedMarketplaces` as advanced read-only registry entries — parseable and displayable but flagged as internal/advanced in the registry metadata.
- `strictKnownMarketplaces` is not a boolean; it is a structured managed-only marketplace allowlist
- `allowedMcpServers` and `deniedMcpServers` are structured rule arrays, not plain string arrays
- sandbox should be treated as a nested object family, not a bag of flat keys

## Deliverables

### 1. `SettingsKeyRegistry`

Create `ClaudeConfigManager/Infrastructure/Parsers/SettingsKeyRegistry.swift` with:

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
- memory and CLAUDE.md behavior (including `autoMemoryEnabled` and `claudeMdExcludes` as first-class keys)
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
- merge hint for resolver work

Nested families like `sandbox`, `statusLine`, `fileSuggestion`, `worktree`, and marketplace source objects should be representable without forcing the parser to flatten everything prematurely.

### 3. `SettingsParser.swift` updates

Update `SettingsParser.parse()` so that:

- known keys are validated against the registry
- unknown keys still produce preserved-key info issues
- known keys with type mismatches produce warnings
- existing named-property parsing remains unchanged for now

Do not break:

- `ParseResult<ParsedSettingsDocument>`
- current parser helper signatures
- current parser tests

### 4. Advanced read-only keys

The following keys should be registered with an `advanced` flag in their `SettingsKeyDefinition`:

- `pluginConfigs` — object (per-plugin configuration blobs)
- `skippedPlugins` — string array (plugins the user has declined)
- `skippedMarketplaces` — string array (marketplaces the user has declined)

These keys are parsed and preserved but displayed in an "Advanced / Internal" section in views, not in the main settings categories. They are not verification-gated — they are intentionally exposed as read-only diagnostic data.

## Acceptance criteria

- existing supported keys parse exactly as before
- unknown keys remain preserved and reported
- known keys with wrong types emit warning-level issues
- registry coverage reflects the current verified settings surface rather than the older local estimate
- `autoMemoryEnabled` and `claudeMdExcludes` are first-class registry entries
- `pluginConfigs`, `skippedPlugins`, `skippedMarketplaces` are registered as advanced read-only
- the registry structure is ready for G2 typed accessors and later resolver/validation work

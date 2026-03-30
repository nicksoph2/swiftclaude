# Section B - Discovery and Root Resolution

## Purpose
Define how the app finds Claude-related files under the global user root and selected project roots.

This layer answers where files live and which scopes they belong to. It does not parse file content and it does not apply precedence rules.

## Section goals
- Resolve the effective global Claude root used for discovery
- Scan selected project roots for supported Claude-related files
- Classify discovered files by type and scope
- Produce stable file references for parsers and resolvers
- Support rescans on open, refresh, external file change, and before save

## Key design rules
- Discovery is path-focused, not content-focused
- Discovery must not infer effective values or precedence winners
- Root overrides change lookup locations only
- Missing files are valid states and must be represented explicitly
- Discovery output should be deterministic for the same inputs

## Inputs
- Default user root, typically `~/.claude`
- Optional user-selected global settings root override
- Selected project root folders
- Managed source descriptors when available in the environment

## Outputs
### Root model
A model that captures:
- current global Claude root path
- reason for that path selection
- registered project roots
- bookmark validity
- access status

### Discovery model
A set of discovered file references such as:
- user settings file reference
- user claude json reference
- project shared settings file reference
- project local settings file reference
- project mcp file reference
- instruction file references
- agent file references
- skill directory references
- auto-memory directory references

## Supported file classes in discovery
### User scope
- `settings.json` under global Claude root
- `CLAUDE.md` under global Claude root
- `.claude.json` in the user home location or configured equivalent handling policy
- `agents/`
- `skills/`
- `projects/<project>/memory/`

### Project scope
- `.claude/settings.json`
- `.claude/settings.local.json`
- `.mcp.json`
- `CLAUDE.md`
- `.claude/CLAUDE.md`
- `.claude/agents/`
- `.claude/skills/`

## Suggested Swift types
- `RootLocator`
- `RootResolutionResult`
- `WorkspaceScanner`
- `DiscoveredWorkspace`
- `DiscoveredFile`
- `DiscoveredDirectory`
- `DiscoveryIssue`

## Required behavior
- Validate that selected folders are reachable through sandbox permissions
- Normalize file URLs and identifiers
- Record whether files exist, are unreadable, or are absent
- Support rescans without changing stable file identity rules unnecessarily
- Separate discovery warnings from parser validation issues

## Things deliberately out of scope
- JSON parsing
- markdown import resolution
- precedence merging
- validation beyond path and accessibility checks

## Recommended implementation order
1. Root locator for global Claude root
2. Project scanner for one project root
3. Discovery models and classification enums
4. Rescan triggers and basic file watching
5. Stable identifiers and issue reporting

## Packets in this section
- `B1_ROOT_LOCATOR`
- likely future packets:
  - `B2_PROJECT_SCANNER`
  - `B3_DISCOVERY_MODELS`
  - `B4_FILE_WATCHING_AND_RESCAN`

## Completion condition for Section B
This section is complete enough for Milestone 1 when the app can take the selected roots, enumerate all supported Claude-related file locations, and produce a deterministic discovery graph for parsers and resolvers.

# Packet B2 - Project Scanner

## Goal
Implement recursive scanning beneath resolved roots and discover Claude-related files and directories without parsing file contents.

## Why this packet exists
After root resolution, the app needs a deterministic scanner that can enumerate supported file locations for one project and the user scope. Later parsers and resolvers depend on stable discovery outputs rather than ad hoc filesystem walks.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_B_DISCOVERY.md`
- output from `B1_ROOT_LOCATOR`

## Dependencies
- `B1_ROOT_LOCATOR`

## Deliverables
- `WorkspaceScanner`
- recursive scanning rules for project roots
- supported-file classification without content parsing
- discovery issues for inaccessible paths and partial scans
- fixture-backed unit tests for representative folder layouts

## Required behavior
### Scan scope
- scan the resolved global Claude root for supported user-scope paths
- scan each resolved project root for supported project-scope paths
- discover both existing files and expected canonical paths that are absent

### Supported paths to classify
- user `settings.json`
- user `CLAUDE.md`
- user `.claude.json`
- user `agents/`
- user `skills/`
- user `projects/<project>/memory/`
- project `.claude/settings.json`
- project `.claude/settings.local.json`
- project `.mcp.json`
- project `CLAUDE.md`
- project `.claude/CLAUDE.md`
- project `.claude/agents/`
- project `.claude/skills/`

### Scanner rules
- do not parse file content
- do not infer precedence winners
- normalize URLs before emitting discovery results
- preserve stable identity for the same physical path across rescans
- surface inaccessible descendants as issues without failing the entire scan
- keep scan order deterministic

## Suggested Swift types
- `WorkspaceScanner`
- `ScanRequest`
- `ScanResult`
- `DiscoveredWorkspace`
- `DiscoveredNode`
- `DiscoveryIssue`

## Acceptance criteria
- scanning the same folder state produces the same discovery ordering and identifiers
- supported files and directories are classified correctly by type and scope
- inaccessible paths are surfaced as issues rather than crashes
- absent canonical files can be represented explicitly for later UI and validation use
- no parsing or resolver behavior is embedded in the scanner

## Out of scope
- parsing JSON or markdown content
- file watching
- precedence resolution
- editing support

## Done when
- later parser packets can consume deterministic discovery outputs without performing their own filesystem walks

## Suggested next packet
- `B3_DISCOVERY_MODELS`

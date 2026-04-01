# Packet B2 - Project Scanner

## Goal
Implement a deterministic scanner that walks beneath roots resolved by `B1_ROOT_LOCATOR` and discovers Claude-related files and directories without parsing file contents.

## Why this packet exists
`B1_ROOT_LOCATOR` provides normalized roots, but later parser and resolver packets need a single discovery output format rather than ad hoc filesystem walks. This packet creates that scan step and keeps discovery strictly path-based.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_B_DISCOVERY.md`
- output models from `B1_ROOT_LOCATOR`

## Dependencies
- `B1_ROOT_LOCATOR`

## Deliverables
- `WorkspaceScanner` service for user scope and project scope scanning
- scan request/result models suitable for one-shot scans
- path classification rules for supported Claude-related files/directories
- issue reporting for inaccessible descendants and partial scan results
- deterministic ordering rules for emitted discovery results
- unit tests for representative folder layouts (present, missing, inaccessible)

## Required behavior
### Scan inputs
- accept one resolved global root and zero or more resolved project roots from `B1`
- use only roots marked accessible for traversal
- preserve root-level access issues from `B1` without re-resolving root policy

### Scan coverage
- scan user scope beneath resolved global root for supported user paths
- scan each resolved project root for supported project paths
- recurse where needed to enumerate agent files and skill directories
- discover canonical paths even when absent so downstream UI/parsers can represent "missing" explicitly

### Supported paths to classify
- user `.claude/settings.json`
- user `.claude/CLAUDE.md`
- user home `.claude.json` (policy supplied by discovery section rules)
- user `.claude/agents/` and agent markdown files beneath it
- user `.claude/skills/` and `SKILL.md` entries beneath it
- user `.claude/projects/<project>/memory/`
- project `.claude/settings.json`
- project `.claude/settings.local.json`
- project `.mcp.json`
- project `CLAUDE.md`
- project `.claude/CLAUDE.md`
- project `.claude/agents/` and agent markdown files beneath it
- project `.claude/skills/` and `SKILL.md` entries beneath it

### Scanner constraints
- do not parse JSON or markdown content
- do not run precedence, merge, or resolver logic
- normalize emitted URLs/paths consistently with `B1` identity rules
- keep output ordering deterministic for equal filesystem state
- surface unreadable descendants as discovery issues without aborting the full scan

## Suggested Swift types
- `WorkspaceScanner`
- `ScanRequest`
- `ScanResult`
- `DiscoveredWorkspace`
- `DiscoveredFile`
- `DiscoveredDirectory`
- `DiscoveredPathStatus`
- `DiscoveryIssue`

## Acceptance criteria
- Same scan inputs and filesystem state produce identical discovery ordering and stable identities
- Supported files/directories are classified correctly by scope and kind
- Missing canonical paths are represented explicitly, not silently dropped
- Inaccessible descendants are reported as issues while other paths still scan
- Scanner output contains no parsed content and no effective-value decisions

## Out of scope
- parser implementation details (`C*` packets)
- discovery output type finalization beyond what scanner needs (`B3_DISCOVERY_MODELS`)
- file watching or incremental re-scan orchestration
- resolver precedence or merge behavior (`D*` packets)
- edit/write flows

## Done when
A later packet can consume scanner output as the single discovery source for supported Claude-related paths, without adding its own filesystem traversal.

## Suggested next packet
- `B3_DISCOVERY_MODELS`

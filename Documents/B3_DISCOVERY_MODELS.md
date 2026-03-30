# Packet B3 - Discovery Models

## Goal
Define the shared discovery domain models that carry normalized file and directory references from discovery into parser and resolver packets.

## Why this packet exists
`B1_ROOT_LOCATOR` and `B2_PROJECT_SCANNER` produce path-level discovery data, but later packets need a single typed contract for identity, scope, provenance, status, and discovery issues. This packet establishes that contract so parser and resolver code does not reinterpret raw URLs.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/AI_DRAFT_OTHERS_HANDOFF.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_B_DISCOVERY.md`
- outputs from `B1_ROOT_LOCATOR`
- outputs from `B2_PROJECT_SCANNER`

## Dependencies
- `B1_ROOT_LOCATOR`
- `B2_PROJECT_SCANNER`

## Deliverables
- shared discovery model types used across discovery, parser, and resolver layers
- typed references for discovered files and directories
- scope identity types covering user, project, managed, and memory-related locations
- path provenance and path-state enums
- discovery issue model with typed targets and severity
- ordering and identity invariants documented for downstream consumers
- unit tests for model identity, sorting, and issue targeting

## Required behavior
### Model layering
- keep these models content-agnostic and path-focused
- avoid parser state, schema errors, or resolver precedence fields in discovery models
- make models usable as read-only inputs to all `C*` and `D*` packets

### Stable identity
- every discovered path has a stable identity object that is deterministic for the same normalized path and scope
- identity must separate logical ownership (scope) from physical location (path)
- identity must remain stable whether the path exists or is currently missing

### Scope identity
- represent top-level scope as user or project
- for project scope, include a stable project identity derived from normalized project root
- support managed/imported source annotations without changing the base scope model
- support auto-memory paths as a first-class discovery location, not an untyped extra

### Path provenance and status
- represent how a path entered discovery (canonical expected path, override-root canonical path, descendant scan hit)
- represent path state independently of provenance (present, missing, unreadable, inaccessible, unsupported)
- preserve normalized absolute URL/path plus display path helpers for UI use

### File and directory classification
- classify each discovered node as file or directory with explicit kind enums
- cover all currently supported classes in Section B and Project Index
- keep unknown/unclassified paths out of this model unless explicitly allowed by scanner policy

### Issue modeling
- discovery issues must be separate from parser and semantic validation issues
- issues must target one of: root, workspace, file, directory, or scan operation
- include issue code, severity, and optional underlying error context for diagnostics
- support partial discovery completion where issues coexist with usable discovered entries

### Deterministic ordering
- define a single sort order for discovered files/directories and issues
- ordering keys should be explicit and documented (scope, class, normalized path, stable id)
- downstream layers must not need to add ad hoc sorting for deterministic behavior

## Suggested Swift types
- `DiscoveryWorkspace`
- `DiscoveryScope`
- `ProjectDiscoveryScope`
- `ScopeIdentity`
- `DiscoveryPathID`
- `DiscoveredNode`
- `DiscoveredFile`
- `DiscoveredDirectory`
- `DiscoveryFileKind`
- `DiscoveryDirectoryKind`
- `PathProvenance`
- `DiscoveryPathStatus`
- `DiscoveryIssue`
- `DiscoveryIssueTarget`
- `DiscoveryIssueCode`
- `DiscoveryIssueSeverity`
- `DiscoveryOrdering`

## Suggested type-shape expectations
- `ScopeIdentity`: logical scope key (`user` or project id), optional project root identity, optional managed/imported source tag
- `DiscoveryPathID`: stable id derived from normalized path + scope identity + node class
- `DiscoveredFile` / `DiscoveredDirectory`: identity, scope, kind, normalized path, provenance, status
- `DiscoveryWorkspace`: resolved root references plus discovered nodes plus discovery issues
- `PathProvenance`: `canonicalExpected`, `rootOverrideCanonical`, `descendantDiscovered`
- `DiscoveryPathStatus`: `present`, `missing`, `unreadable`, `inaccessible`, `unsupported`
- `DiscoveryIssue`: id, target, code, severity, message, optional underlying error payload

## Acceptance criteria
- scanner output can be represented fully with these models without lossy ad hoc fields
- parser packets can consume discovered file references without redefining scope or path identity
- resolver packets can inspect provenance/scope/status without re-walking filesystem paths
- missing canonical paths and inaccessible paths are modeled explicitly and distinctly
- discovery issues can coexist with partial success and still allow downstream work
- deterministic ordering is reproducible for equivalent discovery inputs

## Out of scope
- root selection policy and resolution logic (`B1_ROOT_LOCATOR`)
- recursive traversal and classification execution (`B2_PROJECT_SCANNER`)
- file parsing and AST/content models (`C*` packets)
- precedence, merge, and effective-value computation (`D*` packets)
- UI rendering structure for discovery/session views

## Done when
Discovery, parser, and resolver packets can all share these discovery models as the single path-level contract without introducing duplicate identity/provenance abstractions.

## Suggested next packet
- `C1_SETTINGS_JSON_PARSER`

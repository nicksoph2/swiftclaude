# Packet B3 - Discovery Models

## Goal
Define the shared typed discovery contract that `B1_ROOT_LOCATOR` and `B2_PROJECT_SCANNER` output, and that `C*` parsers plus `D*` resolvers consume.

## Why this packet exists
Discovery results must move through the system as stable, explicit models rather than ad hoc paths. This packet defines that contract once so later packets do not re-infer scope, identity, provenance, or path status.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/AI_DRAFT_OTHERS_HANDOFF.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_B_DISCOVERY.md`
- output models from `B1_ROOT_LOCATOR`
- scan/classification output from `B2_PROJECT_SCANNER`

## Dependencies
- `B1_ROOT_LOCATOR`
- `B2_PROJECT_SCANNER`

## Deliverables
- canonical discovery domain types shared across discovery, parser, and resolver layers
- typed file and directory references with stable identity
- scope identity model for user/project ownership and optional managed-source tagging
- path provenance and path status enums
- discovery issue model with typed targets and severity
- deterministic ordering and identity rules documented for downstream consumers
- unit tests for identity stability, ordering, and issue targeting

## Required behavior
### Separation of concerns
- keep discovery models path-focused and content-agnostic
- do not include parser syntax/schema state in discovery nodes
- do not include precedence, merge method, or effective-value fields

### Stable identity contract
- every discovered node must carry a stable identity object
- stable identity is derived from normalized absolute path + logical scope identity + node class
- identity remains stable even when status changes (`present` to `missing`, `present` to `unreadable`, etc.)
- parser and resolver packets must be able to key caches and traces off this identity

### Typed file and directory references
- represent discovered paths as explicit file or directory nodes, not a single loose path type
- include normalized absolute path for deterministic machine behavior
- include display path helper(s) for UI labels without losing normalized identity
- include node kind enums that map to supported Section B file classes

### Scope identity
- represent logical owner scope separately from physical path
- support user scope identity
- support project scope identity with stable project key derived from normalized project root
- allow optional source annotation for managed/imported provenance without replacing scope identity
- include auto-memory location as a first-class discovery location and kind

### Path provenance
- track how a node entered discovery, independently of whether it currently exists
- support provenance values at minimum:
  - `canonicalExpected`
  - `rootOverrideCanonical`
  - `descendantDiscovered`
- provenance should be preserved through parser and resolver pipelines for source traces

### Path status
- represent filesystem availability separately from provenance
- support status values at minimum:
  - `present`
  - `missing`
  - `unreadable`
  - `inaccessible`
  - `unsupported`
- missing canonical entries must remain representable so UI and resolvers can distinguish "not found" from "not applicable"

### Discovery issue model
- discovery issues are distinct from parser and semantic validation issues
- each issue targets one typed subject: root, workspace, file node, directory node, or scan operation
- include stable code, severity, user-facing message, and optional diagnostic context
- allow partial success: usable nodes may coexist with one or more discovery issues

### Deterministic ordering
- define one canonical sort strategy for nodes and issues
- ordering keys should be explicit and stable: scope key, node kind, normalized path, stable id
- downstream packets should not need to impose additional sorting for deterministic behavior

## Suggested Swift types
- `DiscoveryWorkspace`
- `DiscoveryScopeIdentity`
- `ProjectScopeIdentity`
- `DiscoveryPathID`
- `DiscoveredNode`
- `DiscoveredFile`
- `DiscoveredDirectory`
- `DiscoveryFileKind`
- `DiscoveryDirectoryKind`
- `DiscoveryNodeClass`
- `DiscoveryPathProvenance`
- `DiscoveryPathStatus`
- `DiscoveryIssue`
- `DiscoveryIssueTarget`
- `DiscoveryIssueCode`
- `DiscoveryIssueSeverity`
- `DiscoveryOrdering`

## Suggested type-shape expectations
- `DiscoveryWorkspace`
  - resolved root references (from `B1`)
  - discovered file and directory nodes (from `B2`)
  - discovery issues
  - scan timestamp or monotonic scan token if needed for change detection

- `DiscoveryScopeIdentity`
  - `scopeKind` (`user` or `project`)
  - `projectID` (present when `project`)
  - optional managed/imported source descriptor

- `DiscoveryPathID`
  - stable deterministic key built from:
    - normalized absolute path
    - `DiscoveryScopeIdentity`
    - `DiscoveryNodeClass` (`file` or `directory`)

- `DiscoveredFile` and `DiscoveredDirectory`
  - `id: DiscoveryPathID`
  - `scope: DiscoveryScopeIdentity`
  - typed `kind`
  - normalized absolute path
  - display path helper
  - provenance
  - status

- `DiscoveryIssue`
  - stable issue id
  - typed target
  - code
  - severity
  - user message
  - optional underlying error/debug context

## Parser and resolver handoff contract
- `C*` parser packets consume only `DiscoveredFile` entries with compatible `DiscoveryFileKind`
- parser outputs should carry the originating `DiscoveryPathID` for traceability
- `D*` resolver packets can use scope identity, provenance, and status without re-walking filesystem paths
- resolver/source-trace models should be able to reference discovery identity directly

## Acceptance criteria
- `B2` scanner output can be represented without lossy adapter fields
- all supported Section B file classes map to explicit file/directory kinds
- scope identity, provenance, and status are explicit and non-overlapping
- missing and inaccessible states are modeled distinctly and survive handoff to downstream packets
- parser and resolver packet drafts can reference these models without redefining discovery identity
- deterministic ordering is reproducible for equivalent discovery inputs

## Out of scope
- global root choice policy and project root normalization logic (`B1_ROOT_LOCATOR`)
- filesystem traversal and path classification execution (`B2_PROJECT_SCANNER`)
- parser AST/content schemas (`C*` packets)
- precedence, merge algorithms, and effective value computation (`D*` packets)
- UI rendering concerns

## Done when
Discovery, parser, and resolver layers share one path-level contract for identity, scope, provenance, status, and discovery issues, with no duplicate abstractions for those concerns.

## Suggested next packet
- `C1_SETTINGS_JSON_PARSER`

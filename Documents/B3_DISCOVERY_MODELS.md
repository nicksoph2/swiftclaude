# Packet B3 - Discovery Models

## Goal
Define the shared typed discovery outputs used by scanners, parsers, resolvers, and validation.

## Why this packet exists
The scanner and root locator need a stable contract for discovered files, directories, scope identity, provenance, and issues. Later packets should depend on explicit models instead of loose URL passing.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_B_DISCOVERY.md`
- outputs from `B1_ROOT_LOCATOR` and `B2_PROJECT_SCANNER`

## Dependencies
- `B1_ROOT_LOCATOR`
- `B2_PROJECT_SCANNER`

## Deliverables
- shared discovery domain models
- path and scope identity types
- file-class and directory-class enums
- issue models suitable for discovery output
- tests for model construction and stable identity behavior

## Required behavior
### Discovery identity
- distinguish logical scope from physical path
- support user, project, local, managed, imported, and auto-memory source identity where relevant
- represent both existing and absent canonical paths

### Discovery metadata
- record file class or directory class
- record existence and accessibility status
- record provenance such as default path, override path, or discovered descendant
- preserve normalized URLs and stable identifiers

### Issue representation
- separate path-access issues from later parse and semantic validation issues
- allow issues to point to roots, files, or directories
- support partial discovery states without making the entire workspace unusable

## Suggested Swift types
- `DiscoveryScope`
- `DiscoverySourceKind`
- `DiscoveredFile`
- `DiscoveredDirectory`
- `DiscoveredWorkspace`
- `FileClass`
- `DirectoryClass`
- `DiscoveryIdentity`
- `DiscoveryIssue`

## Acceptance criteria
- parser packets can take typed file references from these models without new path-shape decisions
- resolver packets can inspect scope and provenance without reinterpreting raw URLs
- the models can represent missing canonical files and inaccessible paths cleanly
- file and directory classification remains path-focused rather than content-focused

## Out of scope
- recursive scanning logic
- file parsing
- precedence rules
- UI rendering decisions

## Done when
- discovery outputs are stable enough to become the shared contract between discovery, parsing, validation, and resolution

## Suggested next packet
- `C1_SETTINGS_JSON_PARSER`

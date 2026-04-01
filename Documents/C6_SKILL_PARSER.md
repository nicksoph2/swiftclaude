# Packet C6 - Skill Parser

## Goal
Parse a single skill directory into a typed `ParsedSkillDocument` based on `SKILL.md`, including frontmatter, markdown body, supporting-file references, and parse-time diagnostics.

## Why this packet exists
Resolver and validation packets need stable parsed skill inputs before they can reason about visibility, precedence, or semantic correctness. This packet isolates file-shape parsing so downstream systems do not re-parse raw markdown.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/AI_DRAFT_OTHERS_HANDOFF.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_C_PARSERS.md`
- discovered skill directory paths under `.claude/skills/`
- shared parse primitives from earlier parser packets (`ParseResult`, `SyntaxIssue`, `SourceRange`, `SourceFileReference`)

## Dependencies
- `B3_DISCOVERY_MODELS`
- `C1_SETTINGS_JSON_PARSER` (for shared parse result / issue primitives)

## Deliverables
- `SkillParser`
- `ParsedSkillDocument`
- `ParsedSkillFrontmatter`
- `ParsedSkillSupportingReference`
- `SkillDirectoryMetadata`
- parser fixtures and unit tests for valid and malformed skill directories

## Required behavior
### Parser entry and scope
- parse one discovered skill directory at a time
- accept at minimum: skill directory URL/path and expected `SKILL.md` path
- do not inspect other skill directories during a single parse call

### `SKILL.md` handling
- treat `SKILL.md` as the canonical entry document for a skill directory
- if `SKILL.md` is missing, return a parse result with diagnostics rather than throwing fatal errors
- preserve the raw markdown body exactly after frontmatter splitting

### Supported frontmatter
Frontmatter is optional YAML at the top of `SKILL.md`.

Parser must support typed decoding for these V1 keys:
- `name: String`
- `description: String`
- `version: String`
- `tags: [String]`

Rules:
- frontmatter must decode as a YAML object/map when present
- unknown keys must be preserved in a raw/loosely typed container for forward compatibility
- known keys with wrong value types emit syntax diagnostics and remain unset in typed fields
- parser does not enforce semantic requirements like “name must be unique”

### Supporting-file references
Extract supporting references from the markdown body of `SKILL.md`.

V1 extraction targets:
- markdown links: `[label](path)`
- markdown images: `![label](path)`

V1 path classes:
- relative local paths (for example `references/guide.md`, `./scripts/run.sh`, `../shared/file.md`)
- absolute filesystem paths (for example `/tmp/example.txt`)

For each extracted reference, capture:
- original token text
- normalized path text (string normalization only)
- inferred reference kind (`link` or `image`)
- whether shape is parseable as a local file reference

Guardrails:
- do not resolve references to actual files in this packet
- do not classify trust/safety/executability
- do not compute dependency graphs

### Directory metadata
Capture basic per-directory metadata needed by later packets:
- skill root path
- `SKILL.md` path
- `hasSkillMarkdown` boolean

### Parse-time diagnostics
Emit `SyntaxIssue` diagnostics for parse-layer failures, including source path and range when practical.

Minimum diagnostic cases:
- missing `SKILL.md`
- malformed frontmatter delimiters
- malformed YAML frontmatter
- non-object frontmatter shape
- known frontmatter key with wrong type
- malformed markdown reference token shape

## Suggested Swift types
- `SkillParser`
- `ParsedSkillDocument`
- `ParsedSkillFrontmatter`
- `ParsedSkillSupportingReference`
- `SkillDirectoryMetadata`
- `SyntaxIssue`

## Suggested model sketch (non-binding)
```swift
struct ParsedSkillDocument {
    let directory: SkillDirectoryMetadata
    let frontmatter: ParsedSkillFrontmatter?
    let body: String?
    let supportingReferences: [ParsedSkillSupportingReference]
}

struct ParsedSkillFrontmatter {
    let name: String?
    let description: String?
    let version: String?
    let tags: [String]?
    let unknownFields: [String: YAMLValue]
}

struct ParsedSkillSupportingReference {
    let originalToken: String
    let normalizedPath: String?
    let kind: ReferenceKind
    let isParseableLocalFileReference: Bool
}
```

## Test fixture guidance
Create parser fixtures for:
- valid skill with frontmatter + body + multiple references
- valid skill with no frontmatter
- valid frontmatter containing unknown keys
- malformed frontmatter delimiters
- malformed YAML frontmatter
- known frontmatter keys with wrong types
- missing `SKILL.md`
- malformed markdown link/image token patterns
- relative path edge cases (`./`, `../`, spaces, punctuation)

## Acceptance criteria
- parser outputs typed `ParsedSkillDocument` values for valid inputs
- parser returns diagnostics (not crashes) for malformed/missing structures
- supported frontmatter keys decode into typed fields
- unknown frontmatter keys are preserved
- supporting references are extracted into typed records for downstream use
- output is parser-only and does not embed resolver or active-skill semantics

## Out of scope
- skill precedence across scopes
- active/inactive/selected skill semantics
- filesystem existence checks for referenced supporting files
- semantic validation of frontmatter meaning
- runtime behavior of scripts or referenced assets
- Session/UI presentation logic

## Done when
- `SkillParser` and related models exist with fixture-backed tests
- required diagnostics are emitted for malformed inputs
- downstream resolver/validation packets can consume parsed skill models without re-parsing markdown

## Suggested next packet
- `D1_RESOLVER_MODELS`

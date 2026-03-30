# Packet C4 - Claude Markdown Parser

## Goal
Implement parsing for Claude instruction markdown files (`CLAUDE.md`) into typed instruction documents that preserve full raw content and extract import tokens (for example `@path/to/file`) with parse-time diagnostics only.

## Why this packet exists
Instruction resolution packets need a stable parsed representation of instruction markdown before they can apply scope precedence, load order, recursion handling, and import graph policies. This packet isolates file parsing and token extraction so downstream logic can operate on typed parser output instead of reparsing markdown text.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_C_PARSERS.md`
- discovery file references for:
  - user `~/.claude/CLAUDE.md`
  - project root `CLAUDE.md`
  - project local `.claude/CLAUDE.md`
- shared parser infrastructure from prior parser packets (`ParseResult`, `SyntaxIssue`, `SourceFileReference`)

## Dependencies
- `B3_DISCOVERY_MODELS` should exist (or minimal stubs) to provide discovered instruction file references
- `C1_SETTINGS_JSON_PARSER` for shared parser result and syntax issue primitives

## Deliverables
- `ClaudeMdParser`
- `ParsedClaudeMdDocument`
- import token extraction model (token text, parsed path segment, source range/line metadata)
- parse-time diagnostics for malformed import token shapes
- fixture-backed parser unit tests

## Required behavior
### File family boundary
- parse only user-authored instruction markdown files (`CLAUDE.md` in supported user/project locations)
- do not parse agent markdown in this packet (`C5` owns that)
- do not parse skill markdown in this packet (`C6` owns that)
- keep auto-memory behavior separate from user-authored instruction parsing

### Raw markdown preservation
- preserve the full original markdown body as read from disk
- preserve line breaks and ordering exactly so downstream features can use original text for previews/provenance
- do not normalize markdown structure in this packet

### Import token extraction
- detect import token occurrences such as `@path/to/file`
- support multiple tokens in one file
- preserve token occurrence order
- preserve duplicate textual tokens as separate occurrences
- capture per-token source metadata where practical:
  - byte/character range or line/column range
  - raw token text (including leading `@`)
  - parsed import path segment without `@`

### Parse-time token diagnostics
Emit parse-time `SyntaxIssue` entries for malformed token shapes while still returning the parsed document body and valid tokens. Include source path and location metadata where possible.

Malformed-token diagnostics should cover at least:
- token containing only `@` with no path
- token with surrounding whitespace that breaks expected shape (for example `@ path`)
- token path containing disallowed control/newline characters
- token that is obviously truncated by markdown punctuation edge cases when shape cannot be interpreted safely

### Explicit scope guardrails
- do not resolve import paths to actual files
- do not apply recursion, cycle detection, or depth limits
- do not apply load order, scope precedence, or deduplication policy
- do not classify imports as user/project/managed/auto-memory at parse time
- do not merge instruction documents

## Suggested Swift types
- `ParsedClaudeMdDocument`
- `ParsedInstructionBody`
- `ParsedImportToken`
- `ImportTokenParseStatus`
- `ImportTokenDiagnosticContext`
- `SyntaxIssue`
- `SourceRange`

## Suggested model shape (non-binding)
```swift
struct ParsedClaudeMdDocument {
    let source: SourceFileReference
    let rawBody: String
    let imports: [ParsedImportToken]
}

struct ParsedImportToken {
    let rawToken: String
    let rawPath: String?
    let range: SourceRange?
    let status: ImportTokenParseStatus
}

enum ImportTokenParseStatus {
    case valid
    case malformed
}
```

## Test fixture guidance
Create fixtures for:
- markdown with no imports
- markdown with one valid import token
- markdown with multiple valid import tokens
- markdown with repeated identical tokens (preserve as separate occurrences)
- markdown mixing valid and malformed tokens
- malformed token: standalone `@`
- malformed token: `@ path` (space immediately after `@`)
- malformed token: token containing newline/control character edge case
- markdown where `@` appears in normal prose/email-like text and should not be treated as an import token unless it matches token shape

## Acceptance criteria
- parser returns a typed `ParsedClaudeMdDocument` containing full raw markdown body
- valid import tokens are extracted in source order with token-level metadata
- malformed token shapes generate clear parse-time diagnostics without dropping the raw body
- parser does not perform path resolution, recursion, precedence, or graph behavior
- unit tests cover both valid token extraction and malformed-token diagnostics

## Out of scope
- import graph construction
- import path resolution to discovered files
- cycle detection and recursion policy
- instruction load order and precedence
- auto-memory selection/attachment behavior
- Session UI rendering

## Done when
- `ClaudeMdParser` exists and produces typed document output plus parse-time token diagnostics
- fixture-backed tests validate core extraction behavior and malformed-token handling
- downstream resolver packet (`D4_INSTRUCTION_RESOLUTION`) can consume parsed instruction documents and token lists without reparsing markdown

## Suggested next packet
- `C5_AGENT_PARSER`

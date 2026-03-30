# Packet C5 - Agent Parser

## Goal
Implement parser-only support for agent markdown files under `.claude/agents/`, producing typed output for YAML frontmatter and prompt body with reliable parse-time diagnostics for malformed frontmatter.

## Why this packet exists
Resolver and validation layers need a stable parsed representation of agent files before any higher-level behavior is applied. This packet isolates file parsing so downstream packets can focus on semantic concerns (for example duplicate names, precedence, tool policy) without reparsing markdown.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_C_PARSERS.md`
- discovered agent file references for:
  - user scope `.claude/agents/*.md`
  - project scope `.claude/agents/*.md`
- shared parser primitives from earlier packets (`ParseResult`, `SyntaxIssue`, `SourceFileReference`, `SourceRange`)

## Dependencies
- `B3_DISCOVERY_MODELS` for discovered agent file references
- `C1_SETTINGS_JSON_PARSER` (or shared parser primitives extracted from it) for parse result and syntax issue shape

## Deliverables
- `AgentParser`
- `ParsedAgentDocument`
- typed frontmatter model for known fields
- unknown-frontmatter field preservation
- exact prompt-body preservation
- parse-time diagnostics for malformed/invalid frontmatter structure
- fixture-backed parser unit tests

## Required behavior
### File family boundary
- parse only agent markdown files under discovered `.claude/agents/` directories
- do not parse `CLAUDE.md` instruction files (`C4` owns those)
- do not parse skill `SKILL.md` files (`C6` owns those)

### Frontmatter split contract
- frontmatter is recognized only when the document begins with a YAML fence (`---`) at the start of the file
- frontmatter ends at the next matching fence line
- text after closing fence is prompt body
- if no valid opening frontmatter fence is present, parse entire file as body-only document
- if opening fence exists but closing fence is missing, emit syntax issue and keep recoverable body output

### Frontmatter parse contract
- parse frontmatter as YAML
- require top-level YAML mapping/object for typed extraction
- known keys to parse:
  - `name`: string
  - `description`: string
  - `tools`: list of strings (preserve order)
  - optional MCP-related metadata keys only as raw/unknown unless formally typed in this packet
- preserve unknown keys in raw frontmatter map for forward compatibility

### Prompt body preservation
- preserve prompt body exactly as read after frontmatter split
- preserve ordering and line breaks
- do not normalize markdown formatting
- do not interpret prompt semantics

### Parse-time diagnostics
Emit `SyntaxIssue` records for parse-shape problems, including source path and range/key-path where practical:
- malformed YAML syntax
- missing closing frontmatter fence
- frontmatter top-level value is not an object
- known key has wrong value type (`name`, `description`, `tools`, list item non-string)
- structurally unsupported frontmatter shape that cannot be safely normalized

Recovery behavior:
- parser should still return `ParsedAgentDocument` when possible, with partial fields and raw body preserved
- diagnostics should be additive, not fatal, unless file cannot be read at all

### Explicit parser guardrails
- do not perform duplicate-name detection
- do not apply user-vs-project precedence
- do not decide active/visible agent sets
- do not validate tool existence/permissions beyond parse-time type shape
- do not evaluate MCP runtime connectivity or behavior

## Suggested Swift types
- `ParsedAgentDocument`
- `ParsedAgentFrontmatter`
- `ParsedAgentToolEntry`
- `AgentFrontmatterParseState`
- `SyntaxIssue`
- `SourceRange`

## Suggested model shape (non-binding)
```swift
struct ParsedAgentDocument {
    let source: SourceFileReference
    let frontmatter: ParsedAgentFrontmatter?
    let rawFrontmatter: [String: YAMLValue]?
    let promptBody: String
}

struct ParsedAgentFrontmatter {
    let name: String?
    let description: String?
    let tools: [ParsedAgentToolEntry]
    let unknownFields: [String: YAMLValue]
}

struct ParsedAgentToolEntry {
    let rawValue: String
}
```

## Test fixture guidance
Create fixtures for at least:
- valid agent with frontmatter + body
- valid agent with unknown frontmatter fields preserved
- valid body-only agent file (no frontmatter)
- malformed YAML frontmatter
- missing closing frontmatter fence
- frontmatter top-level non-object (for example scalar/list)
- wrong types for `name`, `description`, `tools`
- `tools` list with mixed valid/invalid entries (diagnostics + partial recovery)
- empty file and whitespace-only file handling

## Acceptance criteria
- parser returns typed `ParsedAgentDocument` with exact prompt body preservation
- known frontmatter fields parse to typed properties when valid
- unknown fields are preserved for forward compatibility
- malformed frontmatter and type mismatches produce clear parse-time diagnostics
- parser recovers with usable output for malformed-but-readable files
- output is directly consumable by later resolver (`D6`) and validator (`E2`/`E3`) packets without reparsing markdown

## Out of scope
- duplicate-name resolution
- scope precedence and winner selection
- semantic completeness checks (for example requiring non-empty `name`)
- tool policy validation and runtime checks
- Session UI rendering concerns

## Done when
- `AgentParser` exists and is covered by fixture-backed tests for valid and malformed frontmatter cases
- parser outputs typed agent documents plus source-attributed parse-time diagnostics
- later semantic packets can rely on parser output as the single parsing source of truth

## Suggested next packet
- `C6_SKILL_PARSER`

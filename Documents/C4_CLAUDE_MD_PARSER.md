# Packet C4 - Claude Markdown Parser

## Goal
Implement parsing for Claude instruction markdown files and extract import tokens without performing full resolution.

## Why this packet exists
Instruction resolution depends on preserving raw markdown bodies and discovered import references while keeping parse-time concerns separate from load-order and recursion behavior.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_C_PARSERS.md`
- discovery file references for user and project `CLAUDE.md` files

## Dependencies
- `B3_DISCOVERY_MODELS` should exist or be stubbed enough to supply file references

## Deliverables
- `ClaudeMdParser`
- `ParsedClaudeMdDocument`
- import token extraction
- parse-time diagnostics for malformed import token shapes
- fixture-backed unit tests

## Required behavior
### Parsing scope
- preserve raw markdown body
- extract import tokens such as `@path/to/file`
- capture token location metadata where practical
- keep comments and non-import content intact in the raw body

### Separation rules
- do not resolve import paths here
- do not apply load order or scope precedence here
- keep auto-memory behavior separate from user-authored markdown parsing

## Suggested Swift types
- `ParsedClaudeMdDocument`
- `ParsedImportToken`
- `ImportTokenKind`
- `SourceRange`
- `SyntaxIssue`

## Test fixture guidance
Create fixtures for:
- markdown without imports
- markdown with one valid import
- markdown with multiple imports
- malformed import token examples
- duplicate textual imports preserved as separate token occurrences

## Acceptance criteria
- parser preserves the markdown body and extracts import references cleanly
- malformed token shapes produce diagnostics without preventing body capture
- no recursive import resolution or load-order logic is implemented here

## Out of scope
- import graph resolution
- cycle detection
- auto-memory selection logic
- Session UI rendering

## Done when
- instruction resolver packets can consume parsed markdown documents and import tokens without reparsing files

## Suggested next packet
- `C5_AGENT_PARSER`

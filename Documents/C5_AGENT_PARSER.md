# Packet C5 - Agent Parser

## Goal
Implement parsing for agent markdown files with YAML frontmatter and prompt body.

## Why this packet exists
The app needs typed agent definitions before it can reason about duplicate names, precedence, visibility, and diagnostics in the Session view.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_C_PARSERS.md`
- discovery file references for agent markdown files

## Dependencies
- `B3_DISCOVERY_MODELS` should exist or be stubbed enough to supply file references

## Deliverables
- `AgentParser`
- `ParsedAgentDocument`
- frontmatter and body parsing
- parse-time diagnostics for malformed frontmatter
- fixture-backed unit tests

## Required behavior
### Supported fields
- name
- description
- tools
- optional MCP-related metadata if the file family supports it
- prompt body

### Parser rules
- separate YAML frontmatter from markdown body
- preserve raw body content
- capture malformed frontmatter as syntax issues
- do not implement duplicate-name or precedence behavior here

## Suggested Swift types
- `ParsedAgentDocument`
- `ParsedAgentFrontmatter`
- `ParsedToolReference`
- `SyntaxIssue`
- `SourceRange`

## Test fixture guidance
Create fixtures for:
- valid agent with required fields
- valid agent with optional fields
- malformed frontmatter
- missing required fields represented for later semantic validation
- unexpected field preservation if useful

## Acceptance criteria
- valid agent files parse into a typed document with body content preserved
- malformed YAML produces clear syntax issues
- parser output is suitable for later agent-resolution packets

## Out of scope
- duplicate-name handling
- user versus project precedence
- tool validation semantics
- Session UI rendering

## Done when
- later resolver and validation packets can consume parsed agent definitions without reparsing markdown

## Suggested next packet
- `C6_SKILL_PARSER`

# Packet C6 - Skill Parser

## Goal
Implement parsing for skill directories centered on `SKILL.md`, including frontmatter, body content, and supporting-file references.

## Why this packet exists
Skill visibility and validation depend on a parser that understands the primary skill document and the local directory context without mixing in later resolver behavior.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_C_PARSERS.md`
- discovery directory references for skill directories

## Dependencies
- `B3_DISCOVERY_MODELS` should exist or be stubbed enough to supply directory references

## Deliverables
- `SkillParser`
- `ParsedSkillDocument`
- typed frontmatter model
- supporting-file reference extraction
- fixture-backed unit tests

## Required behavior
### Parsing scope
- parse `SKILL.md` within a discovered skill directory
- preserve frontmatter and markdown body
- record supporting file references when the document points to local assets, scripts, or references
- record basic directory metadata such as the skill root path

### Parser rules
- do not implement active-skill semantics here
- do not resolve cross-skill precedence here
- keep parser output focused on the contents and local references of one skill directory

## Suggested Swift types
- `ParsedSkillDocument`
- `ParsedSkillFrontmatter`
- `ParsedSupportingReference`
- `SkillDirectoryMetadata`
- `SyntaxIssue`

## Test fixture guidance
Create fixtures for:
- valid skill directory with `SKILL.md`
- valid frontmatter plus supporting references
- malformed frontmatter
- missing `SKILL.md`
- references to missing supporting files captured for later semantic validation

## Acceptance criteria
- valid skill directories parse into typed skill documents
- malformed frontmatter produces clear syntax diagnostics
- parser output preserves enough context for later visibility and validation packets

## Out of scope
- skill precedence across scopes
- enablement semantics
- editor behavior
- Session UI rendering

## Done when
- later resolver packets can consume parsed skill documents and directory metadata without ad hoc parsing

## Suggested next packet
- `D1_RESOLVER_MODELS`

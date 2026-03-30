# Packet I3 - Parser Tests

## Goal
Define the parser-focused test plan and fixture coverage for supported file families.

## Why this packet exists
Parsers are foundational, and they need repeatable coverage for valid, invalid, and forward-compatible cases before resolver logic can be trusted.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_I_FIXTURES_AND_TESTS.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/I1_FIXTURE_LAYOUT.md`

## Dependencies
- `I1_FIXTURE_LAYOUT`
- parser packets from Section C

## Deliverables
- parser test plan
- fixture-to-test mapping for each supported file family
- expected-issue strategy for invalid cases
- representative snapshot strategy where useful

## Required behavior
- cover settings parser
- cover `~/.claude.json` parser
- cover `.mcp.json` parser
- cover `CLAUDE.md` parser
- cover agent parser
- cover skill parser
- include forward-compatibility cases for unknown fields where relevant

## Suggested Swift types
- `ParserTestCase`
- `ExpectedSyntaxIssueSet`
- `ExpectedParsedShape`

## Acceptance criteria
- each supported parser family has a clear deterministic test strategy
- invalid and partial cases are first-class, not afterthoughts
- parser tests remain distinct from validation and resolver tests

## Out of scope
- semantic validation tests
- resolver tests
- UI tests

## Done when
- the project has a clear parser-testing contract that implementation packets can follow directly

## Suggested next packet
- `E1_VALIDATION_MODELS`

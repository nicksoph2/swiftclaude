# Packet I3 - Parser Tests

## Goal
Define and implement deterministic parser test coverage across all supported file families, including valid, invalid, and forward-compatibility cases.

## Why this packet exists
Parsers are foundational to resolver correctness. If parser behavior regresses, downstream effective-state output becomes unreliable.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_I_FIXTURES_AND_TESTS.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/I1_FIXTURE_LAYOUT.md`
- parser packet outputs from Section C

## Dependencies
- `I1_FIXTURE_LAYOUT`
- Section C parser implementations (`C1` through `C6`)

## Deliverables
- parser test matrix by file family
- fixture-to-test mapping for valid/invalid/edge cases
- expected syntax-issue assertion strategy
- optional structured snapshot strategy for parsed outputs

## Required behavior
### Coverage matrix
Cover at minimum:
- settings parser (`C1`)
- `~/.claude.json` parser (`C2`)
- `.mcp.json` parser (`C3`)
- instruction markdown parser (`C4`)
- agent parser (`C5`)
- skill parser (`C6`)

### Assertion strategy
- assert typed parse output fields
- assert syntax issue code/severity/source attribution
- assert unknown-field preservation/forward-compat behavior where applicable
- assert deterministic ordering in token/reference extraction outputs

### Invalid-case emphasis
- malformed syntax
- wrong top-level shape
- wrong value types for known keys
- missing expected structures
- mixed valid+invalid content where parser should preserve partial output

## Suggested Swift types
- `ParserTestCase`
- `ExpectedSyntaxIssueSet`
- `ExpectedParsedShape`
- `FixtureBackedParserAssertion`

## Test fixture guidance
Create parser fixture packs for:
- one minimal valid case per parser family (`C1` through `C6`)
- malformed syntax cases for each parser family where applicable
- wrong-type known-key cases for each parser family
- unknown-field preservation cases for forward compatibility
- mixed valid+invalid cases that should preserve partial parse output

## Acceptance criteria
- each parser family has deterministic, fixture-backed test coverage
- invalid/partial/forward-compatible cases are first-class
- parser tests remain separate from semantic and resolver assertions

## Out of scope
- semantic validation test rules
- resolver precedence/merge tests
- UI test automation

## Done when
- parser behavior across all supported families is protected by stable, packet-aligned tests

## Suggested next packet
- `E1_VALIDATION_MODELS`

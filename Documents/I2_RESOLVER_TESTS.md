# Packet I2 - Resolver Tests

## Goal
Define and implement deterministic resolver test coverage for precedence, merge, imports, MCP resolution, agent/skill visibility, and Session projection integrity.

## Why this packet exists
Resolver behavior is core product risk. Deterministic tests are required to trust effective-state output and provenance across complex multi-source scenarios.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_I_FIXTURES_AND_TESTS.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/I1_FIXTURE_LAYOUT.md`
- resolver packet outputs from Section D

## Dependencies
- `I1_FIXTURE_LAYOUT`
- Section D resolver implementations (`D2` through `D7`)

## Deliverables
- resolver test matrix by resolver family
- fixture-to-test mapping for major precedence/merge/conflict scenarios
- expected-output strategy (assertion structs and optional snapshots)
- tests for aggregate Session projection integrity

## Required behavior
### Coverage matrix
At minimum include deterministic tests for:
- settings precedence (`D2`)
- settings merge rules (`D3`)
- instruction load order/import graph (`D4`)
- MCP precedence/override/conflict behavior (`D5`)
- agent/skill visibility and overrides (`D6`)
- projection assembly and partial-state handling (`D7`)

### Assertion strategy
- assert effective values/entries
- assert winning/participating source traces
- assert issue codes and severities
- assert deterministic ordering for collections

### Snapshot guidance
- use snapshots only for stable structured outputs where it improves readability
- keep snapshot format deterministic and compact
- pair snapshots with targeted field-level assertions for critical invariants

## Suggested Swift types
- `ResolverTestCase`
- `ExpectedResolutionTrace`
- `ExpectedIssueSet`
- `ExpectedSessionProjection`

## Test fixture guidance
Create resolver fixture packs for:
- settings precedence-only cases (`D2`)
- settings merge-focused cases (`D3`)
- instruction graph cases (nested, cycle, missing import) (`D4`)
- MCP override/conflict/env-note cases (`D5`)
- agent/skill override and invalid-entry cases (`D6`)
- full and partial aggregate projection cases (`D7`)

## Acceptance criteria
- each resolver family has representative deterministic coverage
- fixture mapping clearly ties cases to behavior under test
- projection integrity can be verified without invoking UI code
- test failures localize regressions to a resolver family or rule set

## Out of scope
- parser-only tests
- UI interaction tests
- live filesystem integration tests unless explicitly scoped later

## Done when
- Section D behavior is protected by deterministic tests that are easy to extend as new cases appear

## Suggested next packet
- `I3_PARSER_TESTS`

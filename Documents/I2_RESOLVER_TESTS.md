# Packet I2 - Resolver Tests

## Goal
Define the resolver-focused test plan and test structure for precedence, merge behavior, imports, MCP, visibility, and Session projection.

## Why this packet exists
Resolver behavior is the core product risk. The project needs deterministic tests that verify effective-state behavior and provenance without relying on manual inspection.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_I_FIXTURES_AND_TESTS.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/I1_FIXTURE_LAYOUT.md`

## Dependencies
- `I1_FIXTURE_LAYOUT`
- resolver packets from Section D

## Deliverables
- resolver test plan
- fixture-to-test mapping for precedence and merge scenarios
- snapshot or expected-output strategy where helpful
- representative test categories per resolver family

## Required behavior
- cover settings precedence and merge behavior
- cover instruction load order and import diagnostics
- cover MCP precedence and duplicate handling
- cover agent and skill visibility
- cover aggregate Session projection integrity

## Suggested Swift types
- `ResolverTestCase`
- `ExpectedResolutionTrace`
- `ExpectedSessionProjection`

## Acceptance criteria
- each major resolver family has a clear deterministic test strategy
- fixture mapping is explicit enough for implementation packets
- projection integrity can be verified without UI dependence

## Out of scope
- parser-focused tests
- UI test automation
- live filesystem integration tests unless deliberately scoped later

## Done when
- the project has a clear resolver-testing contract that later implementation work can follow directly

## Suggested next packet
- `I3_PARSER_TESTS`

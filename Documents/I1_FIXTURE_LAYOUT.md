# Packet I1 - Fixture Layout

## Goal
Define the shared test fixture directory structure and naming strategy used across parser, resolver, validation, and Session tests.

## Why this packet exists
Without a stable fixture system, later tests will duplicate data, drift in format, and become hard to maintain.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_I_FIXTURES_AND_TESTS.md`

## Dependencies
- none required

## Deliverables
- fixture directory structure
- naming conventions
- representative valid and invalid fixture categories
- expected-output and snapshot placement rules

## Required behavior
- separate fixtures by file family and test purpose
- include both valid and invalid examples
- support parser tests, resolver tests, validation tests, and Session projection tests
- keep fixture names stable and descriptive

## Suggested Swift types
- `FixtureDescriptor`
- `FixtureLoader`
- `ExpectedSnapshotReference`

## Acceptance criteria
- later packets can reference a shared fixture layout without inventing new ad hoc directories
- fixture naming conventions are consistent
- expected-output placement is clear enough for snapshot and comparison tests

## Out of scope
- actual parser tests
- actual resolver tests
- UI test automation details

## Done when
- the project has a stable fixture contract that later test packets can reuse directly

## Suggested next packet
- `I2_RESOLVER_TESTS`

# Section I - Fixtures and Tests

## Purpose
Define the shared fixture layout, test architecture, and packet-aligned verification strategy for discovery, parsing, resolution, validation, and Session projection.

## Section goals
- create reusable fixture structure for supported file families
- provide parser-focused test coverage
- provide resolver-focused test coverage
- support deterministic snapshot-style verification where useful
- keep test assets aligned to packet boundaries

## Key design rules
- fixtures should be minimal but representative
- valid and invalid cases should both be first-class
- tests should prefer deterministic local data over live environment dependence
- fixture reuse should reduce duplication across packets
- packet docs should point to the fixture categories they rely on

## Responsibilities in this section
### Fixture layout
- directory structure
- naming conventions
- expected-output placement
- mapping between fixture sets and packet-level tests

### Parser tests
- syntax and structure coverage
- forward-compatibility cases
- malformed file examples

### Resolver tests
- precedence
- merge behavior
- import graph behavior
- visibility and projection integrity

## Suggested Swift types
- `FixtureLoader`
- `FixtureDescriptor`
- `ExpectedIssueSet`
- `SnapshotAssertionSupport`

## Interfaces with other sections
- uses discovery outputs from Section B
- uses parser outputs from Section C
- uses resolver outputs from Section D
- uses validation outputs from Section E
- supports UI packets where stable projection snapshots are helpful

## Risks
- fixture sprawl without naming discipline
- brittle snapshot tests that encode incidental formatting
- under-testing invalid and partial states

## Recommended implementation order
1. fixture layout
2. resolver tests
3. parser tests

## Packets in this section
- `I1_FIXTURE_LAYOUT`
- likely future packets:
  - `I2_RESOLVER_TESTS`
  - `I3_PARSER_TESTS`

## Completion condition for Section I
This section is complete enough when the project has a reusable fixture system and clear packet-aligned tests for parsers, resolvers, validation, and Session projection.

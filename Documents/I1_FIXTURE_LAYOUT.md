# Packet I1 - Fixture Layout

## Goal
Define a shared fixture directory contract and naming strategy used by parser, resolver, validation, and Session projection/view-state tests.

## Why this packet exists
Without a stable fixture layout, test data drifts and duplicate ad hoc fixtures spread across the repo. This packet creates a reusable test-data foundation for all later packets.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_I_FIXTURES_AND_TESTS.md`

## Dependencies
- none

## Deliverables
- canonical fixture directory structure
- naming convention rules for inputs and expected outputs
- mapping rules between fixtures and packet-level tests
- guidance for snapshot/expected-result storage and updates

## Required behavior
### Directory contract
Define a deterministic fixture tree, for example:
- `.../Fixtures/parsers/<family>/<case>/`
- `.../Fixtures/resolvers/<family>/<case>/`
- `.../Fixtures/validation/<family>/<case>/`
- `.../Fixtures/session/<case>/`

### Naming conventions
- stable, descriptive case ids (`valid_basic`, `invalid_missing_name`, `override_project_wins`)
- paired `input` and `expected` artifacts where applicable
- optional `README.md` per fixture family for local conventions

### Data format guidance
- keep fixtures minimal but representative
- store expected outputs in deterministic formats (JSON or line-oriented text snapshots)
- keep parser syntax issues, resolver traces, and validation issues in separately named expected files where useful

### Maintenance guidance
- fixture updates should be intentional and reviewable
- avoid coupling expected snapshots to incidental formatting
- document when a fixture is shared across multiple packet tests

## Suggested Swift types
- `FixtureDescriptor`
- `FixtureLoader`
- `ExpectedSnapshotReference`
- `FixtureCaseID`

## Test fixture guidance
Create meta-fixtures/examples for:
- one parser family fixture set with valid/invalid paired cases
- one resolver family fixture set with precedence and conflict cases
- one validation fixture set with expected issue outputs
- one Session projection fixture set with mixed valid/invalid family inputs
- one shared fixture case reused by two packet-level test suites

## Acceptance criteria
- packets C, D, E, and F can all reference one fixture contract
- case naming is consistent and human-readable
- expected-output placement is clear enough for deterministic assertions

## Out of scope
- implementing parser tests
- implementing resolver tests
- implementing UI automation

## Done when
- test packets can use fixture paths and naming rules without inventing additional structure

## Suggested next packet
- `I2_RESOLVER_TESTS`

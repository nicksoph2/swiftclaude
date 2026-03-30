# Test Fixture Contract

This directory defines the canonical fixture layout used by parser, resolver, validation, and session projection tests.

## Directory contract

- `parsers/<family>/<case>/`
- `resolvers/<family>/<case>/`
- `validation/<family>/<case>/`
- `session/<case>/`
- `shared/<family>/<case>/`

Each case uses:

- `input/` for source fixture artifacts
- `expected/` for deterministic expected outputs (JSON or line-oriented text)

## Case naming

Case IDs must be stable and descriptive, for example:

- `valid_basic`
- `invalid_json_trailing_comma`
- `override_project_wins`
- `permissions_allow_deny_overlap`

## Expected output files

When applicable, expected outputs should be split by concern to keep updates reviewable:

- `parser_issues.json`
- `resolved_snapshot.json`
- `validation_issues.json`
- `projection_summary.json`

## Mapping to packet-level suites

- Parser packets (`C*`, `I3`) should read from `parsers/` and may reuse `shared/`.
- Resolver packets (`D*`, `I2`) should read from `resolvers/` and may reuse `shared/`.
- Validation packets (`E*`) should read from `validation/`.
- Session projection/view packets (`F*`) should read from `session/`.

The shared fixture `shared/settings/override_project_wins` is intentionally reused by parser and resolver suites.

## Snapshot update guidance

- Keep fixture inputs minimal but representative.
- Update expected artifacts intentionally with code changes.
- Avoid encoding incidental formatting in expected snapshots.
- Prefer deterministic JSON with stable key ordering in generators.

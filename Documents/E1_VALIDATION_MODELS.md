# Packet E1 - Validation Models

## Goal
Define shared validation models, codes, severities, and result containers used by schema and semantic validators and surfaced in Session.

## Why this packet exists
Validation must be consistent across parser, resolver, and UI layers. This packet establishes the common issue language so later validators can be implemented without ad hoc models.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_E_VALIDATION.md`
- parser and resolver issue-shape conventions from Sections C and D

## Dependencies
- none hard-required

## Deliverables
- shared validation issue domain types
- severity taxonomy and stage/category taxonomy
- stable validation code strategy (namespaced where useful)
- source-reference model with optional range and related-source links
- validation result aggregation utilities
- unit tests for model construction/aggregation behavior

## Required behavior
### Issue model behavior
Validation issues should support:
- stable code
- severity (`info`, `warning`, `error`)
- category/stage (schema vs semantic)
- user-facing message
- source reference (file, directory, virtual source)
- optional source range and related references

### Result aggregation behavior
- allow combining multiple validation passes into one result
- preserve deterministic issue ordering for tests/UI
- support summary helpers (error count, warning count, blocking-state checks)

### Interop behavior
- allow parser syntax issues to be bridged or displayed alongside validation issues without duplicating issue models unnecessarily
- remain independent from UI formatting and resolver precedence rules

## Suggested Swift types
- `ValidationIssue`
- `ValidationSeverity`
- `ValidationCategory`
- `ValidationCode`
- `ValidationSourceReference`
- `ValidationResult`
- `ValidationSummary`

## Suggested model shape (non-binding)
```swift
struct ValidationIssue {
    let code: ValidationCode
    let severity: ValidationSeverity
    let category: ValidationCategory
    let message: String
    let source: ValidationSourceReference?
}

struct ValidationResult {
    let issues: [ValidationIssue]
}
```

## Acceptance criteria
- shared validation types are expressive enough for E2 and E3
- issue codes are stable and test-friendly
- source references can represent file, directory, and virtual origins
- aggregation utilities support deterministic combined outputs

## Out of scope
- schema rules implementation
- semantic rules implementation
- UI layout/presentation behavior

## Done when
- E2 and E3 can implement validators directly on top of shared validation models without redefining foundational types

## Suggested next packet
- `E2_SCHEMA_VALIDATION`

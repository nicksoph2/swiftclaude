# Packet E1 - Validation Models

## Goal
Define the shared models used to represent validation issues and validation results across the project.

## Why this packet exists
Before implementing validators, the project needs stable issue types, severity levels, codes, source references, and result containers that can be shared by parser, resolver, and UI layers.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_E_VALIDATION.md`

## Dependencies
- none required beyond the existing parser and resolver model shapes the types should anticipate

## Deliverables
- shared validation domain types
- severity taxonomy
- stable validation code strategy
- source-link and optional range support
- unit tests for representative issue construction

## Suggested Swift types
- `ValidationIssue`
- `ValidationSeverity`
- `ValidationCode`
- `ValidationCategory`
- `ValidationResult`
- `ValidationSourceReference`

## Required behavior
- support at least warning and error levels, plus informational notes if useful
- allow a validation issue to point to a source path, logical source identity, and optional range
- support aggregation of multiple issue lists into one result
- remain usable for parser-derived, schema-derived, and semantic issues

## Acceptance criteria
- shared validation types are expressive enough for later schema and semantic validators
- issue codes are stable enough for tests and UI filtering
- source references can point to files, directories, or virtual sources when needed

## Out of scope
- actual schema validation rules
- actual semantic validation rules
- UI rendering details

## Done when
- later validation packets can build behavior on top of these shared types without redefining the basic issue model

## Suggested next packet
- `E2_SCHEMA_VALIDATION`

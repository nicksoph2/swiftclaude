# Packet E2 - Schema Validation

## Goal
Implement schema-level validation for supported parsed file families after syntax parsing succeeds.

## Why this packet exists
Parsers can confirm syntax and basic shapes, but the app also needs post-parse validation for required fields, incompatible shapes, and other structural correctness that is easier to express after typed parsing.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_E_VALIDATION.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/E1_VALIDATION_MODELS.md`
- parser outputs from Section C

## Dependencies
- `E1_VALIDATION_MODELS`
- parser packet outputs from Section C

## Deliverables
- `SchemaValidator`
- schema checks for supported file families
- issue aggregation into shared validation results
- tests for representative valid and invalid structures

## Required behavior
### Validation scope
- required-field checks
- invalid enum-like values where documented
- incompatible nested value shapes
- unsupported combinations that are structural rather than semantic

### Validation rules
- do not duplicate raw JSON or YAML syntax parsing
- allow per-file-family validation while sharing issue models
- keep cross-file meaning checks for semantic validation

## Suggested Swift types
- `SchemaValidator`
- `SchemaValidationContext`
- `ValidationIssue`
- `ValidationResult`

## Acceptance criteria
- representative parsed documents can be schema-validated without reparsing raw text
- structural mistakes produce shared validation issues with source references
- cross-file meaning checks remain deferred to semantic validation

## Out of scope
- semantic validation across scopes and files
- UI rendering
- save gating policy

## Done when
- parsed outputs from supported file families can be structurally validated with stable issue codes and source attribution

## Suggested next packet
- `E3_SEMANTIC_VALIDATION`

# Packet E2 - Schema Validation

## Goal
Implement schema-level validation for parsed file families using typed parser outputs and shared validation models.

## Why this packet exists
Parsing confirms syntax and basic structure, but additional structural checks (required fields, allowed shapes, incompatible combinations) are needed before semantic cross-file checks.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_E_VALIDATION.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/E1_VALIDATION_MODELS.md`
- parser outputs from Section C packets

## Dependencies
- `E1_VALIDATION_MODELS`
- parser packets in Section C

## Deliverables
- `SchemaValidator`
- per-file-family schema validation routines
- issue aggregation into `ValidationResult`
- deterministic tests for valid and invalid structural cases

## Required behavior
### Scope and boundaries
- operate on parsed outputs only (no raw text reparsing)
- validate one document/family at a time plus simple family-specific constraints
- defer cross-file/cross-scope meaning checks to `E3`

### Family coverage targets
Include schema checks for:
- settings parser outputs (`C1`)
- `~/.claude.json` parser outputs (`C2`)
- `.mcp.json` parser outputs (`C3`)
- instruction markdown parser outputs (`C4`) where schema-like shape rules apply
- agent parser outputs (`C5`)
- skill parser outputs (`C6`)

### Typical schema checks
- required fields present where required by file family
- allowed type/shape checks on modeled fields
- incompatible structural combinations within same document
- malformed optional sections represented as validation issues

### Diagnostics behavior
- produce stable validation codes per family/rule
- attach concrete source references and optional ranges when available
- preserve deterministic issue order

## Suggested Swift types
- `SchemaValidator`
- `SchemaValidationContext`
- `ValidationIssue`
- `ValidationResult`

## Test fixture guidance
Create tests for:
- valid document per supported family
- required-field omissions
- invalid type/shape combinations per family
- structurally incompatible combinations within one document
- deterministic issue ordering for multiple issues in one file

## Acceptance criteria
- representative parsed documents can be schema-validated without reparsing
- structural problems surface as shared validation issues with concrete attribution
- schema validation remains distinct from semantic/policy checks

## Out of scope
- cross-file semantic checks
- precedence or resolver behavior
- UI rendering rules

## Done when
- all supported parser families have schema checks and deterministic tests using shared validation models

## Suggested next packet
- `E3_SEMANTIC_VALIDATION`

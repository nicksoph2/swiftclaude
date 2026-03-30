# Packet E3 - Semantic Validation

## Goal
Implement semantic validation across parsed and resolved project data.

## Why this packet exists
Some problems are not syntax or schema issues. The app needs cross-file and cross-scope checks for duplicates, broken assumptions, unreachable references, and similar meaning-level problems.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_E_VALIDATION.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/E1_VALIDATION_MODELS.md`
- parser outputs from Section C
- resolver outputs from Section D

## Dependencies
- `E1_VALIDATION_MODELS`
- parser packet outputs from Section C
- resolver packet outputs from Section D

## Deliverables
- `SemanticValidator`
- semantic checks across scopes and file families
- issue aggregation into shared validation results
- tests for representative semantic error cases

## Required behavior
### Semantic issue families
- duplicate agent or skill names
- unreachable or cyclic imports
- invalid tool references or unsupported tool syntax where that is a meaning-level concern
- unresolved environment references
- bad scope assumptions and conflicting definitions across sources

### Validation rules
- use parsed and resolved outputs rather than raw-text reparsing
- keep semantic issues attributable to concrete sources and traces
- distinguish semantic warnings from outright blocking errors where appropriate

## Suggested Swift types
- `SemanticValidator`
- `SemanticValidationContext`
- `ValidationIssue`
- `ValidationResult`

## Acceptance criteria
- representative cross-file and cross-scope problems produce shared semantic issues
- issue attribution remains concrete enough for Session inspection
- semantic validation stays separate from parsing and precedence logic

## Out of scope
- UI rendering
- editing workflows
- canonical save output

## Done when
- the app can explain meaning-level problems in parsed and resolved project state using shared validation models

## Suggested next packet
- `F1_SESSION_SETTINGS_VIEW`

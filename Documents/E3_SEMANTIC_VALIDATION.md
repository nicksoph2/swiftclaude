# Packet E3 - Semantic Validation

## Goal
Implement semantic validation across parsed and resolved state to detect meaning-level problems that are not syntax or schema errors.

## Why this packet exists
Users need actionable diagnostics for cross-file and cross-scope conflicts such as duplicate definitions, unresolved references, and incompatible assumptions. This packet provides those checks using resolver outputs.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_E_VALIDATION.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/E1_VALIDATION_MODELS.md`
- parser outputs from Section C
- resolver outputs from Section D

## Dependencies
- `E1_VALIDATION_MODELS`
- parser outputs from Section C
- resolver outputs from Section D

## Deliverables
- `SemanticValidator`
- semantic rule sets for major resolver families
- aggregated semantic validation result
- deterministic tests for representative semantic conflicts

## Required behavior
### Semantic issue families
Cover at least:
- duplicate/conflicting agent and skill identities
- unresolved, cyclic, or unreachable instruction imports
- conflicting MCP server assumptions across scopes
- unresolved environment-dependent references where semantic policy requires reporting
- invalid cross-scope assumptions (for example expected source missing or overridden unexpectedly)

### Resolver-aware checks
- use resolver outputs and traces instead of reparsing text
- preserve source and related-source attribution on each issue
- classify severity consistently (`warning` vs `error`) by rule intent

### De-duplication and layering
- avoid duplicating parser syntax issues as semantic issues unless additional semantic context is added
- aggregate semantic issues alongside schema/syntax for Session visibility

## Suggested Swift types
- `SemanticValidator`
- `SemanticValidationContext`
- `SemanticRule`
- `ValidationIssue`
- `ValidationResult`

## Test fixture guidance
Create tests for:
- duplicate agent/skill identity scenarios
- unresolved/cyclic instruction imports propagated from resolver state
- MCP conflict scenarios requiring semantic warnings/errors
- environment-reference semantic warnings
- mixed schema+semantic issue sets with deterministic ordering

## Acceptance criteria
- representative cross-file and cross-scope problems produce attributable semantic issues
- semantic checks consume resolver outputs directly
- semantic rules remain separate from parser and precedence implementation

## Out of scope
- UI rendering behavior
- file editing/gating workflows
- canonical write formatting

## Done when
- semantic validation can explain meaning-level conflicts in effective Session state using shared models and deterministic tests

## Suggested next packet
- `F1_SESSION_SETTINGS_VIEW`

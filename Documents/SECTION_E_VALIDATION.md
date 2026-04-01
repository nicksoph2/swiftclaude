# Section E - Validation

## Purpose
Define how the app produces syntax, schema, and semantic validation results across discovered, parsed, and resolved Claude-related content.

## Section goals
- create shared validation models and severity taxonomy
- validate parsed documents beyond basic syntax
- validate semantic relationships across files and scopes
- provide issue output suitable for Session inspection and later editor previews
- keep validation separate from parsing and resolution

## Key design rules
- syntax diagnostics stay with parsers, but validation can aggregate them
- schema validation checks structural correctness after parsing
- semantic validation checks cross-file and cross-scope meaning
- validation must not invent a shadow truth store
- issues should remain attributable to concrete sources

## Responsibilities in this section
### Shared validation models
- issue types
- issue codes
- severity and note levels
- source references and optional ranges

### Schema validation
- post-parse shape checks
- required field checks
- incompatible value-shape checks

### Semantic validation
- duplicate names
- unreachable imports
- bad scope assumptions
- unresolved env references
- unsupported tool syntax or other cross-file meaning checks

## Suggested Swift types
- `ValidationIssue`
- `ValidationSeverity`
- `ValidationCode`
- `ValidationResult`
- `SchemaValidator`
- `SemanticValidator`

## Interfaces with other sections
- consumes parse outputs from Section C
- consumes resolved outputs from Section D
- feeds read-only issue presentation in Section F
- feeds save-preview and editor gating in later editing packets

## Risks
- duplicating parser syntax checks in validators
- mixing semantic validation with precedence logic
- making validation rules too UI-specific too early

## Recommended implementation order
1. shared validation models
2. schema validation
3. semantic validation

## Packets in this section
- `E1_VALIDATION_MODELS`
- likely future packets:
  - `E2_SCHEMA_VALIDATION`
  - `E3_SEMANTIC_VALIDATION`

## Completion condition for Section E
This section is complete enough when the app can produce stable, attributable validation results for parsed and resolved inputs without collapsing parser, resolver, and UI concerns into one layer.

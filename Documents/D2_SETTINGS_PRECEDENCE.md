# Packet D2 - Settings Precedence

## Goal
Implement source precedence selection for settings-derived configuration values before deep merge behavior is applied.

## Why this packet exists
The resolver needs an explicit, testable precedence ladder for settings sources so the app can explain which source wins before it applies per-key merge rules.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_D_RESOLVER.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D1_RESOLVER_MODELS.md`
- parsed settings documents from `C1_SETTINGS_JSON_PARSER`
- parsed `~/.claude.json` data when needed for clear separation of responsibilities

## Dependencies
- `C1_SETTINGS_JSON_PARSER`
- `D1_RESOLVER_MODELS`

## Deliverables
- `SettingsResolver` precedence-selection layer
- source-order model for settings candidates
- provenance traces for participating settings sources
- unit tests for precedence scenarios

## Required behavior
### Baseline precedence ladder
1. managed settings
2. command-line arguments
3. project local settings
4. project shared settings
5. user settings

### Resolver rules
- represent missing or invalid sources explicitly
- explain why a winner was chosen
- keep `settings.json` and `~/.claude.json` responsibilities distinct
- prepare inputs for later per-key merge behavior without re-parsing documents

## Suggested Swift types
- `SettingsSourceCandidate`
- `SettingsSourceOrder`
- `ResolvedSettingsSourceSelection`
- `ResolutionTrace`
- `ResolvedValue<T>`

## Acceptance criteria
- precedence selection is deterministic for the same inputs
- winner and participating sources are traceable for each resolved setting candidate
- invalid higher-precedence sources can surface issues without silently hiding lower-precedence candidates
- merge logic remains conceptually separate for the next packet

## Out of scope
- per-key merge behavior
- UI rendering
- canonical save output

## Done when
- settings candidates can be ordered and traced consistently before per-key merge rules are applied

## Suggested next packet
- `D3_SETTINGS_MERGE_RULES`

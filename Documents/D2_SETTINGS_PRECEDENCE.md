# Packet D2 - Settings Precedence

## Goal
Define and implement deterministic precedence selection for settings sources so the resolver can explain, for every settings key, which source had authority before merge policy is applied.

## Why this packet exists
`D1` defines shared resolver models, but not concrete ordering rules. `D2` is where settings authority is decided across managed, CLI, project-local, project-shared, and user settings inputs.

This packet exists to keep responsibilities clean:
- `D2` answers "which source is higher precedence?"
- `D3` answers "how are values merged for this key family?"

Without this split, precedence and merge behavior become entangled and harder to test or explain in Session provenance.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/AI_DRAFT_OTHERS_HANDOFF.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_D_RESOLVER.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D1_RESOLVER_MODELS.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/C1_SETTINGS_JSON_PARSER.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/C2_CLAUDE_JSON_PARSER.md`
- parsed settings documents from `C1_SETTINGS_JSON_PARSER`
- optional parsed `~/.claude.json` document only for boundary checks, not as a settings source

## Dependencies
- `C1_SETTINGS_JSON_PARSER`
- `D1_RESOLVER_MODELS`
- discovery output that identifies:
  - user settings file
  - project shared settings file
  - project local settings file
  - managed policy injection source (if present)
  - CLI override source (if present for the current run)

## Deliverables
- `SettingsResolver` precedence stage that:
  - builds an ordered source-candidate list
  - selects winners by precedence tier
  - records full provenance traces for downstream merge/reporting
- explicit source-tier taxonomy for settings precedence
- deterministic source-selection tests
- fixtures covering missing/invalid source states and boundary confusion

## Required behavior
### Canonical settings source ladder
For settings-family resolution, precedence is:
1. managed settings source
2. CLI settings overrides
3. project local settings (`<project>/.claude/settings.local.json`)
4. project shared settings (`<project>/.claude/settings.json`)
5. user settings (`~/.claude/settings.json`)

Higher items override lower items at the selection layer. This packet does not define merge behavior within or across complex key shapes.

### Source eligibility and normalization
- each candidate source is normalized into a `SettingsSourceCandidate`
- each candidate includes:
  - source identity/provenance (`ResolutionSource`)
  - precedence tier
  - availability (`present`, `missing`, `invalid`, `inaccessible`)
  - parsed settings payload when available
  - parser issues carried forward from C1
- candidate ordering must be deterministic even when some tiers are absent

### Selection rules
- selection runs per settings key family (or equivalent key path abstraction)
- a winner is the highest-precedence candidate that provides that key family with a usable value
- lower-precedence candidates remain in trace as participants/overridden when they contributed competing values
- if no candidate provides a usable value, result is unresolved with explicit notes/issues

### Invalid and missing-source behavior
- missing source:
  - represented explicitly in trace
  - does not block fallback to lower tiers
- invalid source:
  - emits resolution issues with source attribution
  - does not cause silent drop of fallback candidates
  - does not claim winner status for keys that cannot be read from that source

### Determinism requirements
- fixed precedence tiers (no runtime reordering)
- stable tie-breaking inside the same tier (if multiple synthetic/derived entries exist)
- stable participant ordering in trace output for test snapshots

### Boundary rules: `settings.json` vs `~/.claude.json`
- `settings.json` family (`~/.claude/settings.json`, project shared/local settings files) is the only JSON family in this packet's precedence ladder
- `~/.claude.json` is not a substitute source for settings keys in D2
- if `~/.claude.json` contains keys that look like settings keys, they remain `~/.claude.json` parser output and do not enter settings precedence candidates
- responsibilities remain separated for later packets:
  - settings precedence/merge: `D2` + `D3`
  - `~/.claude.json` global/MCP behavior: parser + MCP resolver packets

### Resolver output contract for D3 handoff
`D2` should produce output that `D3` can consume without recomputing precedence:
- ordered candidate set
- per-key winner source id (when resolved)
- per-key participant list
- per-key selection notes/issues
- unresolved keys metadata

## Suggested Swift types
- `SettingsSourceTier` (managed, cli, projectLocal, projectShared, user)
- `SettingsSourceCandidate`
- `SettingsSourceOrdering`
- `ResolvedSettingsSourceSelection`
- `SettingsSelectionEntry`
- `SettingsSelectionTrace`
- `ResolutionSource`
- `ResolutionAvailability`
- `ResolutionIssue`
- `ResolvedValue<Value>`

## Test fixture guidance
Add or extend fixtures/tests for:
- user-only settings source
- user + project shared
- user + project shared + project local
- managed + CLI + project + user full chain
- missing project-local file with valid project-shared fallback
- invalid project-local JSON with valid lower-tier fallback retained
- invalid higher-tier managed/CLI payload behavior (issues + fallback)
- deterministic ordering when tiers are absent
- boundary case: `~/.claude.json` contains `settings.json`-like keys; verify exclusion from D2 candidates

## Acceptance criteria
- precedence tier ordering matches Section D baseline exactly
- settings winner selection is deterministic and independently testable
- winner, participants, and overridden sources are preserved in provenance
- missing/invalid sources are explicit, with attributed issues
- `~/.claude.json` is clearly excluded from settings precedence candidates
- `D3` can consume D2 output directly without re-deriving source order

## Out of scope
- per-key merge method definitions and deep merge behavior (`D3`)
- schema validation and semantic validation policy (`Section E`)
- UI rendering concerns (`Section F`)
- write-back/canonical output formatting

## Done when
- `SettingsResolver` has a dedicated precedence stage that emits deterministic source-selection artifacts
- test coverage proves correct behavior across full source ladder and invalid/missing cases
- packet boundaries remain clean: precedence in `D2`, merge policy in `D3`

## Suggested next packet
- `D3_SETTINGS_MERGE_RULES`

# Packet D3 - Settings Merge Rules

## Goal
Define and implement per-key merge behavior for resolved settings after source precedence is established.

## Why this packet exists
Different settings keys need different merge strategies. The resolver must model scalar override, deep-merge, and collection behavior explicitly so the Session view can explain how effective values were produced.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_D_RESOLVER.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D1_RESOLVER_MODELS.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/D2_SETTINGS_PRECEDENCE.md`
- parsed settings documents from `C1_SETTINGS_JSON_PARSER`

## Dependencies
- `C1_SETTINGS_JSON_PARSER`
- `D1_RESOLVER_MODELS`
- `D2_SETTINGS_PRECEDENCE`

## Deliverables
- merge-rule definitions by settings key or key family
- merge implementation for scalar, object, and collection cases
- provenance traces for merge participants
- unit tests covering representative merge scenarios

## Required behavior
### Merge families
- scalar override for single-value keys
- deep merge for structured objects where supported
- append or de-duplicate behavior for collection-style keys where documented
- permissions and hooks handled by explicit merge policies rather than implicit dictionary merging

### Resolver rules
- preserve which sources participated in the final value
- record the merge method used
- surface conflicting shapes as issues
- keep undocumented assumptions explicit and testable

## Suggested Swift types
- `MergeRule`
- `MergeMethod`
- `MergeContext`
- `MergedSettingsValue`
- `ResolutionIssue`

## Acceptance criteria
- effective settings values include merge-method provenance
- collection and object merges are deterministic
- conflicting value shapes surface issues instead of producing silent data loss
- precedence selection and merge behavior remain separable concepts

## Out of scope
- Session UI rendering
- save-preview formatting
- non-settings resolution families

## Done when
- the resolver can explain both which source won and how multiple sources participated in the effective settings snapshot

## Suggested next packet
- `D4_INSTRUCTION_RESOLUTION`

# Section F - Session UI

## Purpose
Define the read-only Session user interface that presents the effective Claude configuration state and its provenance.

## Section goals
- present resolved settings, instructions, hooks, MCP, agents, and skills
- make winning sources and participating sources visible
- show issues, notes, and completeness clearly
- keep the Session scope read-only from the start
- avoid embedding resolver logic in views

## Key design rules
- Session is computed, not persisted
- Session screens are read-only
- provenance and diagnostics should be first-class UI concerns
- views should consume projection models rather than resolve data themselves
- UI should remain inspectable even when some sources are missing or invalid

## Responsibilities in this section
### Session settings view
- effective values
- winning source
- merge method
- issues and notes

### Session instructions view
- load order
- imports
- startup-loaded instructions
- on-demand memory availability

### Session hooks and integrations views
- effective hooks grouped by event or matcher
- effective MCP servers and overridden definitions

### Session agents and skills view
- visibility by scope
- precedence
- duplicate and invalid-state diagnostics

## Suggested Swift types
- `SessionProjection`
- `SessionScreenModel`
- `SessionIssueBadgeModel`
- `SourceChipModel`

## Interfaces with other sections
- hosted by Section A app shell
- powered by Section D projection outputs
- consumes validation results from Section E
- should stay separate from later editor packets in Section G

## Risks
- leaking resolver logic into view models
- adding editing affordances to Session screens
- hiding provenance details that users need for trust

## Recommended implementation order
1. settings view
2. instructions view
3. hooks view
4. MCP view
5. agents and skills view

## Packets in this section
- `F1_SESSION_SETTINGS_VIEW`
- likely future packets:
  - `F2_SESSION_INSTRUCTIONS_VIEW`
  - `F3_SESSION_HOOKS_VIEW`
  - `F4_SESSION_MCP_VIEW`
  - `F5_SESSION_AGENTS_SKILLS_VIEW`

## Completion condition for Section F
This section is complete enough when the app can present a trustworthy, read-only Session experience with effective values, provenance, and diagnostics across the main resolver families.

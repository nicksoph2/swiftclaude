# Resolver Fixture Matrix

This directory maps deterministic resolver fixture cases to resolver families:

- `settings/override_project_wins` -> D2 settings precedence
- `settings/conflict_allow_deny_overlap` -> D3 settings merge and conflict issues
- `instructions/cycle_and_missing_import` -> D4 instruction load order/import cycle/missing imports
- `mcp/fallback_and_env_notes` -> D5 MCP precedence, fallback, and environment note classifications
- `agents_skills/override_and_invalid_entries` -> D6 visibility override and invalid-entry handling
- `projection/partial_settings_only` -> D7 projection completeness and partial-family behavior

Expected assertions for each case should include:

- effective winners/values
- participant and overridden source traces
- deterministic issue code sets
- deterministic collection ordering

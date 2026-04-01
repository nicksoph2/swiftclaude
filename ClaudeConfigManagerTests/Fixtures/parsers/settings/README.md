# Parser Fixtures - Settings

This family provides paired valid/invalid settings fixtures.

- `valid_basic`: valid baseline shape and scalar/object fields.
- `valid_registry_modern`: registry-backed modern settings coverage, including nested families and advanced read-only keys.
- `valid_full_permissions`: modern permissions object with allow/deny/ask/default mode/additional directories and managed-only flag.
- `valid_mcp_controls`: typed MCP control settings with valid allow/deny restriction rules.
- `valid_worktree_and_ops`: worktree nested object plus the remaining verified operational settings from U2.
- `valid_cleanup_zero`: cleanup period zero remains valid and documents the disable-persistence sentinel.
- `experimental_delegate_mode`: experimental permissions default mode preserved with an info issue.
- `invalid_mcp_controls`: malformed MCP control settings to verify typed rule diagnostics.
- `invalid_permissions`: malformed modern permissions fields to verify info and warning diagnostics.
- `invalid_worktree_ops`: malformed worktree and operational settings to verify enum/range/type diagnostics.
- `invalid_registry_known_type`: known registry keys with wrong types should warn without becoming unsupported.
- `invalid_json_trailing_comma`: malformed JSON to verify syntax diagnostics.

# Parser Fixtures - MCP JSON

Fixture coverage for MCP server-definition shapes. In this codebase, MCP parsing is asserted through `ClaudeJsonParser` MCP field parsing behavior.

- `valid_mcp_transports`: stdio, streamable HTTP, and deprecated SSE transport coverage.
- `invalid_mcp_transports`: empty and ambiguous transport definitions.

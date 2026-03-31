# Packet P3: MCP Transport Types and Per-Server Policy

## Overview

This packet normalizes MCP server definitions across `.mcp.json`, `~/.claude.json`, and managed MCP sources. It adds explicit transport modeling for all current transport types, marks deprecated transports, and handles plugin-provided MCP servers.

## Prerequisites

- G1 and G2 completed (or parseable independently)
- P2 completed (MCP control keys available)

## Pre-read files

- `ClaudeConfigManager/Infrastructure/Parsers/ClaudeJsonParser.swift` — current MCP parsing
- `ClaudeConfigManager/Infrastructure/Parsers/SettingsParser.swift`
- `Documents/AGENT_FRAMEWORK.md`

## Transport types

### stdio (primary)

The most common transport. Server runs as a child process communicating over stdin/stdout.

| Key | Type | Description |
|-----|------|-------------|
| `command` | `String` (required) | Executable path or name |
| `args` | `[String]?` | Command-line arguments |
| `env` | `[String: String]?` | Environment variables |
| `cwd` | `String?` | Working directory |

### http (streamable HTTP)

Modern HTTP-based transport using streamable HTTP protocol.

| Key | Type | Description |
|-----|------|-------------|
| `url` | `String` (required) | HTTP endpoint URL |
| `headers` | `[String: String]?` | HTTP headers (supports env var interpolation) |

### sse (deprecated)

Server-Sent Events transport. Deprecated in favor of streamable HTTP but still supported for backward compatibility.

| Key | Type | Description |
|-----|------|-------------|
| `url` | `String` (required) | SSE endpoint URL |
| `headers` | `[String: String]?` | HTTP headers |

**Parser behavior**: Parse normally but emit an info-level issue noting SSE transport is deprecated.

### Plugin-provided MCP

MCP servers that are bundled with Claude Code plugins. These appear in the effective MCP list but are not directly user-configured.

| Key | Type | Description |
|-----|------|-------------|
| `pluginId` | `String` | Originating plugin identifier |
| `pluginName` | `String?` | Human-readable plugin name |

Plugin-provided servers should be displayed with their plugin provenance and are subject to the same allow/deny restriction rules as other servers.

## Deliverables

### 1. Transport model

```swift
enum McpTransportType: String {
    case stdio
    case http          // streamable HTTP
    case sse           // deprecated
    case plugin        // plugin-provided
    case unknown       // forward compat
}

struct McpServerConfig {
    let name: String
    let transportType: McpTransportType

    // stdio fields
    let command: String?
    let args: [String]?
    let env: [String: String]?
    let cwd: String?

    // http/sse fields
    let url: String?
    let headers: [String: String]?

    // plugin fields
    let pluginId: String?
    let pluginName: String?

    // Source provenance
    let source: McpServerSource  // .mcpJson, .claudeJson, .managed, .plugin

    let unknownFields: [String: JSONValue]?
}

enum McpServerSource {
    case mcpJson(path: String)
    case claudeJson
    case managed
    case plugin(id: String)
}
```

### 2. Parser updates

- Detect transport type from server definition keys:
  - Has `command` → stdio
  - Has `url` and no `command` → check for SSE indicators, default to http
  - Has `pluginId` → plugin
- Parse all transport-specific fields
- Emit deprecation info for SSE transport
- Normalize across all MCP sources (.mcp.json, ~/.claude.json, managed)

### 3. Fixtures

**`valid_mcp_transports/input/.mcp.json`:**
```json
{
  "mcpServers": {
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": { "GITHUB_TOKEN": "..." }
    },
    "remote-api": {
      "url": "https://api.example.com/mcp",
      "headers": { "Authorization": "Bearer token" }
    },
    "legacy-sse": {
      "url": "https://old.example.com/sse",
      "transport": "sse"
    }
  }
}
```

**`invalid_mcp_transports/input/.mcp.json`:**
```json
{
  "mcpServers": {
    "empty": {},
    "ambiguous": {
      "command": "tool",
      "url": "https://example.com"
    }
  }
}
```

### 4. Tests

- stdio transport parses with command, args, env, cwd
- http transport parses with url and headers
- sse transport parses with deprecation info issue
- plugin-provided servers parse with pluginId
- empty server definition → warning
- ambiguous transport (both command and url) → warning with precedence to stdio
- source provenance is correctly set per MCP source file

## Acceptance criteria

- [ ] All three user-configurable transports (stdio, http, sse) parse correctly
- [ ] SSE transport emits deprecation info
- [ ] Plugin-provided servers are representable
- [ ] Source provenance tracks origin file/type
- [ ] McpServerConfig is suitable for resolver restriction evaluation
- [ ] Full test suite passes

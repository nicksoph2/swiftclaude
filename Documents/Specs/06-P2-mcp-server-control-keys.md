# Packet P2: MCP Server Control Keys

## Overview

This packet adds all current MCP control settings that determine which MCP servers may appear, which are enabled/disabled, and which are allowed/denied via typed restriction rules.

## Prerequisites

- G1 and G2 completed (or parseable independently in SettingsParser)

## Pre-read files

- `ClaudeConfigManager/Infrastructure/Parsers/SettingsParser.swift`
- `ClaudeConfigManagerTests/Parsers/SettingsParserTests.swift`
- `Documents/AGENT_FRAMEWORK.md` — Section 11 (MCP controls)

## Required settings

| Key | Type | Scope | Description |
|-----|------|-------|-------------|
| `allowManagedMcpServersOnly` | `Bool` | Managed only | Only managed `allowedMcpServers` are respected |
| `enableAllProjectMcpServers` | `Bool` | Any | Auto-approve all project `.mcp.json` servers |
| `enabledMcpjsonServers` | `[String]` | Any | Named servers from `.mcp.json` to approve |
| `disabledMcpjsonServers` | `[String]` | Any | Named servers from `.mcp.json` to reject |
| `allowedMcpServers` | `[McpRestrictionRule]` | Managed | Allowlist of servers (typed rule objects) |
| `deniedMcpServers` | `[McpRestrictionRule]` | Any | Denylist of servers (typed rule objects) |

**Important**: deny rules take precedence over allow rules per official docs. `deniedMcpServers` merges from all sources even when `allowManagedMcpServersOnly` is true.

## MCP restriction rule model

`allowedMcpServers` and `deniedMcpServers` are arrays of **mutually exclusive discriminated union shapes**. Each rule object matches against exactly one criterion:

### Shape 1: Server name rule
```json
{ "serverName": "github" }
```
Matches the MCP server by its registered name.

### Shape 2: Stdio command rule
```json
{ "serverCommand": ["npx", "-y", "@modelcontextprotocol/server-github"] }
```
Matches the MCP server by its exact stdio command array. The `serverCommand` field must be an array of strings, not a single string.

### Shape 3: Remote URL pattern rule
```json
{ "serverUrl": "https://api.example.com/*" }
```
Matches the MCP server by its remote URL pattern.

**Discriminated union**: Exactly one of `serverName`, `serverCommand`, or `serverUrl` should be present in a rule object. Other keys are ignored for forward compatibility.

## Deliverables

### 1. Typed MCP restriction rule model

```swift
struct McpRestrictionRule {
    // Exactly one of these three should be non-nil
    let serverName: String?      // { "serverName": "github" }
    let serverCommand: [String]? // { "serverCommand": ["npx", ...] }
    let serverUrl: String?       // { "serverUrl": "https://..." }
    let unknownFields: [String: JSONValue]?
}
```

### 2. Parser updates

- Parse `allowManagedMcpServersOnly` as boolean
- Parse `enableAllProjectMcpServers` as boolean
- Parse `enabledMcpjsonServers` and `disabledMcpjsonServers` as string arrays
- Parse `allowedMcpServers` and `deniedMcpServers` as arrays of `McpRestrictionRule` objects
- Validate each rule object has exactly one of: `serverName`, `serverCommand`, or `serverUrl`
- Emit error for rule objects with none of these keys
- Emit error for rule objects with multiple discriminator keys
- Emit warning for `serverCommand` that is not an array
- Emit warning for rule objects that are not JSON objects
- Emit warning for `allowManagedMcpServersOnly` in non-managed scope (if scope info available)
- Preserve unknown fields in each rule object

### 3. Fixtures

**`valid_mcp_controls/input/settings.json`:**
```json
{
  "enableAllProjectMcpServers": true,
  "enabledMcpjsonServers": ["memory", "github"],
  "disabledMcpjsonServers": ["filesystem"],
  "allowedMcpServers": [
    { "serverName": "github" },
    { "serverCommand": ["npx", "-y", "@modelcontextprotocol/server-github"] }
  ],
  "deniedMcpServers": [
    { "serverName": "filesystem" },
    { "serverUrl": "https://untrusted.example.com/*" }
  ]
}
```

**`invalid_mcp_controls/input/settings.json`:**
```json
{
  "enabledMcpjsonServers": "not-an-array",
  "allowedMcpServers": [
    "plain-string-not-object",
    { "serverCommand": "/usr/local/bin/mcp" },
    { "serverName": "ambiguous", "serverCommand": ["npx", "server"] },
    { "unknownKey": "no-discriminator" }
  ],
  "deniedMcpServers": "not-an-array"
}
```

### 4. Tests

- All 6 settings parse when valid
- String arrays parse for `enabledMcpjsonServers` / `disabledMcpjsonServers`
- Rule objects parse with `serverName`, `serverCommand` (array), and `serverUrl` variants
- Exactly one discriminator per rule object enforced:
  - Both `serverName` and `serverCommand` in one rule → error
  - `serverCommand` as string instead of array → error
  - No recognized discriminator key → error
- Non-object in rule array → warning
- Non-array for array-typed settings → error
- Scope restriction for `allowManagedMcpServersOnly` noted

## Acceptance criteria

- [ ] All 6 MCP control settings parse into typed structures
- [ ] Rule objects enforce discriminated union (exactly one of three shapes)
- [ ] `serverCommand` must be an array, not a string
- [ ] Malformed rule entries produce attributable errors/warnings
- [ ] Parsed values suitable for resolver enforcement
- [ ] Full test suite passes

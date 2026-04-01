# Packet 28 — MCP Tool Catalog and Server Health

## Context

The MCP stage currently shows server cards (after Packet 24). This packet adds the full tool catalog — every tool each active server contributes to Claude's capability set, listed alongside the 18 built-in tools — and server health validation that surfaces missing commands or malformed URLs at parse time rather than at runtime.

**Prerequisites: Packets 01, 24 must be complete.**

## Prerequisites

- Packet 01 (pipeline), Packet 24 (MCP card redesign) complete

## Deliverables

### 1. Built-in tool list

The 18 built-in Claude Code tools need to be represented as a static registry. Create `ClaudeConfigManager/Core/Models/BuiltInTools.swift`:

```swift
struct BuiltInTool {
    let name: String
    let description: String
    let inputSummary: String   // e.g. "path: string, content: string"
    let category: ToolCategory
}

enum ToolCategory {
    case fileSystem, shell, search, memory, mcp, agent, other
}
```

Populate the registry with the 18 built-in tools. Find the tool names in the existing codebase (the Tool Execution stage view likely already lists them). If not all 18 are listed in the codebase, use the known Claude Code built-in tools: `read`, `write`, `edit`, `multiedit`, `bash`, `glob`, `grep`, `ls`, `webfetch`, `websearch`, `todo_read`, `todo_write`, `exit_plan_mode`, `notebook_read`, `notebook_edit`, `agent_start`, `computer` (if applicable to the environment), and any others visible in the existing tool execution stage.

### 2. MCP Tool Catalog (K2)

Add a "Tools" section to the MCP stage view, below the server cards.

**`MCPToolCatalogView.swift`**:

A searchable list of all tools available in the current configuration, in two groups:

**Built-in tools** (from `BuiltInTools` registry):
- Each row: tool name (monospace), category badge, description
- Count in group header: "18 built-in tools"

**MCP server tools** (one sub-group per active server):
- Group header: server name, scope badge, server count
- Each row: tool name (monospace), description, input schema summary (parameter names)
- Count per server

**Search bar** at the top: filter both groups by tool name or description.

**Total capability summary**: "Claude has access to X tools in this configuration ([18] built-in + [N] from [M] servers)."

**Tap a built-in tool**: Show a brief popover with tool description and parameters.
**Tap an MCP tool**: Show a popover with server name, transport, full input schema.

### 3. MCP Server Health Check (K4)

Add validation to the MCP parsing step that checks each server's configuration for runtime viability.

**`MCPServerHealthChecker.swift`** in `Infrastructure/Parsers/`:

```swift
struct MCPServerHealthChecker {
    func check(_ servers: [MCPServerDefinition]) -> [MCPHealthIssue]
}

struct MCPHealthIssue {
    let serverId: String
    let severity: IssueSeverity
    let code: MCPHealthCode
    let message: String
}

enum MCPHealthCode {
    case commandNotFound(path: String)
    case commandNotExecutable(path: String)
    case invalidUrl(url: String)
    case missingRequiredField(field: String)
}
```

**Checks:**
- **stdio command exists**: use `FileManager.default.fileExists(atPath: command)` for absolute paths. If the command is a bare name (e.g. `"npx"`), check by resolving via `which` (run `Process` with `which commandName` — non-blocking, just a lookup).
- **stdio command is executable**: use `FileManager.default.isExecutableFile(atPath: resolvedPath)`.
- **HTTP URL valid**: parse with `URL(string:)` and check scheme is `http` or `https`, host is non-empty.
- **Required fields present**: `command` for stdio, `url` for http.

Wire the health checker into `ClaudeJsonParser` (or wherever MCP servers are parsed). Add the resulting `MCPHealthIssue` objects as `SyntaxIssue` entries in the parse result, with the server ID and issue code.

**Visual indicator**: Server cards from Packet 24 already show a validation status icon. With this packet, that icon reflects real health checks rather than just "fields complete".

### 4. MCP Override Visualization (K3)

When user-scope and project-scope both define a server with the same server ID, show the override relationship:

- Active card: full opacity, normal style
- Suppressed card: 50% opacity, "Overridden by [scope name]" banner at the top of the card
- "What differs" expansion: a list of fields that differ between the two definitions (e.g. "command is different", "environment variables differ")

Currently both definitions are shown as equal — this makes the override explicit.

### 5. Tests

Create `ClaudeConfigManagerTests/Parsers/MCPServerHealthCheckerTests.swift`:
- **`testAbsoluteCommandNotFoundEmitsError`** — command path that does not exist → `.commandNotFound` issue
- **`testHttpUrlInvalidSchemeEmitsError`** — URL with `ftp://` scheme → `.invalidUrl` issue
- **`testValidHttpUrlNoIssue`** — `https://server.example.com` → no health issues
- **`testMissingCommandForStdioEmitsError`** — stdio server with no command → `.missingRequiredField`

## Build and Test

```bash
xcodebuild test -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager \
  -destination 'platform=macOS' -quiet 2>&1 | tail -30
```

**Done criteria:**
- Tool catalog shows built-in tools and MCP tools in searchable grouped list
- Total capability count summary is accurate
- Health check runs on parse and surfaces invalid server configs in the Parsing stage
- Override relationship is visually explicit in server cards when two scopes define the same server
- All existing tests pass, build has zero warnings

## Handover Note

Only create `Documents/28-handoff.md` if work deviated from the plan. Record what was completed, what was not, any complications with the `which` command subprocess or file executability checks, and recommended next step.

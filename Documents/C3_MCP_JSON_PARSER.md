# Packet C3 - MCP JSON Parser

## Goal
Implement parsing for project `.mcp.json` files into typed MCP server-definition models, with clear parse-time diagnostics and raw-value provenance for downstream resolver and validation stages.

## Why this packet exists
Cross-scope MCP resolution depends on a stable parsed representation of project-scoped server definitions. This packet isolates `.mcp.json` parsing so transport interpretation, duplicate handling, precedence, and environment expansion can be implemented later in resolver and validation packets without re-parsing JSON.

## Inputs
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/PROJECT_INDEX.md`
- `/Users/nicksoph/Documents/Dev/claude/devDiscoverApp/Documents/SECTION_C_PARSERS.md`
- discovery file references for project `.mcp.json`
- shared parser infrastructure from prior parser packets (`ParseResult`, `SyntaxIssue`, `JSONValue`, `SourceFileReference`)

## Dependencies
- `B3_DISCOVERY_MODELS` should exist (or minimal stubs) to provide `.mcp.json` file references
- `C1_SETTINGS_JSON_PARSER` for shared parser result and syntax issue primitives
- `C2_CLAUDE_JSON_PARSER` for consistency with MCP-adjacent field typing patterns

## Deliverables
- `McpParser`
- `ParsedMcpDocument`
- typed server-definition models for `.mcp.json`
- transport modeling that distinguishes command-based and URL-based forms
- parse-time diagnostics with key-path context
- fixture-backed parser unit tests

## Required behavior
### File family boundary
- parse only project `.mcp.json` in this packet
- do not parse `~/.claude.json` here (that remains in `C2`)
- do not parse `settings.json`-family fields here

### Top-level structure
- expect a top-level JSON object
- support a top-level MCP server container keyed by server id (for example `mcpServers`)
- preserve unknown top-level keys for forward compatibility as raw JSON values
- emit syntax issues for malformed top-level shape or malformed server container shape

### Server definition parsing
For each server id entry:
- require server definition to be a JSON object
- parse shared optional fields:
  - `command` as string
  - `args` as `[String]`
  - `env` as `[String: String]`
  - `url` as string
  - `headers` as `[String: String]`
  - `enabled` as bool when present
  - `source` or metadata string when present
- preserve full raw server object for provenance and future compatibility
- collect per-field type mismatches as syntax issues without aborting the whole document parse

### Transport forms
Model transport as an explicit enum-like shape so resolver code does not infer transport ad hoc:
- command transport when `command` is present (with optional `args`, `env`)
- URL transport when `url` is present (with optional `headers`, `env`)
- mixed-form entries (`command` and `url` both present) should parse but emit a diagnostic indicating ambiguity for later resolution policy
- transport absence should emit a parse-time diagnostic (server object exists but no recognizable transport fields)

### Diagnostics behavior
- report invalid JSON syntax as error
- report non-object top-level document as error
- report non-object server container as error
- report non-object server definitions as error
- report scalar/array/map type mismatches with key-path detail
- report preserved unsupported keys as info-level diagnostics where useful
- include source path and key path on each issue whenever possible

### Explicit scope guardrails
- do not perform precedence merging across scopes
- do not expand environment variables in command, args, env, url, or headers
- do not check process/network reachability
- do not apply semantic policy beyond parse-time shape/type diagnostics

## Suggested Swift types
- `ParsedMcpDocument`
- `ParsedMcpDocumentValue`
- `ParsedMcpServer`
- `ParsedMcpTransport`
- `ParsedMcpCommandTransport`
- `ParsedMcpUrlTransport`
- `McpTransportKind`
- `SyntaxIssue`
- `SyntaxIssueCode` additions for MCP shapes

## Suggested model shape (non-binding)
```swift
struct ParsedMcpDocument {
    let source: SourceFileReference
    let value: ParsedMcpDocumentValue
    let rawTopLevelObject: [String: JSONValue]
    let unsupportedTopLevelKeys: [String: JSONValue]
}

struct ParsedMcpDocumentValue {
    let servers: [String: ParsedMcpServer]
}

struct ParsedMcpServer {
    let id: String
    let command: String?
    let args: [String]?
    let env: [String: String]?
    let url: String?
    let headers: [String: String]?
    let enabled: Bool?
    let source: String?
    let transportKind: McpTransportKind?
    let transport: ParsedMcpTransport?
    let rawObject: [String: JSONValue]
}

enum McpTransportKind {
    case command
    case url
    case ambiguous
    case unknown
}
```

## Test fixture guidance
Create fixtures for:
- valid command-based server (`command` + optional `args`/`env`)
- valid URL-based server (`url` + optional `headers`/`env`)
- mixed valid set with multiple server ids
- invalid JSON syntax
- top-level non-object JSON
- malformed server container shape
- server entry with non-object definition
- malformed `args` (non-array or non-string elements)
- malformed `env` (non-object or non-string values)
- malformed `headers` (non-object or non-string values)
- mixed-form transport (`command` + `url`) diagnostic case
- missing transport fields diagnostic case
- unknown top-level and unknown server-level keys preserved safely

## Acceptance criteria
- valid `.mcp.json` files parse into typed server models consumable by resolver packets
- parse output explicitly models transport form rather than leaving it implicit
- parser emits clear syntax issues for invalid JSON and invalid structural shapes
- parser retains enough raw provenance for downstream diagnostics and forward compatibility
- parser does not perform precedence, environment expansion, or semantic resolution
- unit tests cover core valid paths plus malformed shape/type edge cases

## Out of scope
- precedence between local, project, user, and managed MCP sources
- duplicate server conflict resolution policy
- environment expansion or interpolation
- canonical JSON rendering/writing
- Session UI presentation
- runtime process launch or network connectivity checks

## Done when
- `McpParser` exists and parses project `.mcp.json` into typed document/server models
- parser diagnostics include source-aware issue reporting for malformed structures
- fixture-backed tests validate command transport, URL transport, and major malformed cases
- downstream resolver packet (`D5_MCP_RESOLUTION`) can consume parsed `.mcp.json` without reparsing raw JSON

## Suggested next packet
- `C4_CLAUDE_MD_PARSER`

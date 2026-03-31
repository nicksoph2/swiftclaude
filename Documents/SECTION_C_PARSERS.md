# Section C - Parsers

## Purpose
Parse each supported Claude-related file type into explicit domain models that downstream resolvers and validators can consume.

Parsers should be strict about syntax and structural shape, but they should not decide precedence across scopes. That belongs in the resolver layer.

## Section goals
- Parse supported JSON and markdown-based file formats
- Separate syntax errors from semantic validation issues
- Normalize parsed outputs into stable domain types
- Preserve source location and raw value information where helpful for diagnostics
- Keep each parser focused on one file family

## Supported parser families
### Settings parser
Parses:
- user `settings.json`
- project `.claude/settings.json`
- project `.claude/settings.local.json`

Needs to support:
- documented top-level keys
- hooks object shape
- permissions object shape
- env object shape
- attribution object shape

### Claude JSON parser
Parses:
- `~/.claude.json`

Needs to separate this file from `settings.json` responsibilities and map global preferences, user/local MCP storage, trust state, and related fields.

### MCP parser
Parses:
- project `.mcp.json`
- MCP-related content in `~/.claude.json` as needed by later packets

Needs to normalize server definitions, transports, args, env, url, and headers.

### Claude markdown parser
Parses:
- user and project `CLAUDE.md` files
- import tokens such as `@path/to/file`

Needs to preserve raw markdown body and extract import references without resolving them yet.

### Agent parser
Parses markdown files with YAML frontmatter and body.

Needs to capture:
- name
- description
- tools
- optional MCP server metadata if supported
- prompt body

### Skill parser
Parses `SKILL.md` frontmatter and body inside a skill directory.

Needs to capture:
- frontmatter fields
- body content
- supporting file references
- directory metadata

## Shared parser design rules
- One parser should not inspect unrelated file classes
- Parsers return typed outputs plus syntax issues
- Parsers should preserve source path and useful ranges when available
- Semantic cross-file rules belong in validation or resolver packets, not in basic parsing
- Canonical rendering rules should be centralized later rather than embedded ad hoc in each parser

## Suggested Swift types
- `ParseResult<Value>`
- `SourceFileReference`
- `SourceRange`
- `SyntaxIssue`
- `ParsedSettingsDocument`
- `ParsedClaudeJsonDocument`
- `ParsedMcpDocument`
- `ParsedClaudeMdDocument`
- `ParsedAgentDocument`
- `ParsedSkillDocument`

## Recommended implementation order
1. Settings parser
2. Claude JSON parser
3. MCP parser
4. Claude markdown parser
5. Agent parser
6. Skill parser

## Packets in this section
- `C1_SETTINGS_JSON_PARSER`
- likely future packets:
  - `C2_CLAUDE_JSON_PARSER`
  - `C3_MCP_JSON_PARSER`
  - `C4_CLAUDE_MD_PARSER`
  - `C5_AGENT_PARSER`
  - `C6_SKILL_PARSER`

## Completion condition for Section C
This section is complete enough for Milestone 1 when the app can parse each supported file family into typed models with reliable syntax diagnostics, ready for resolver and validation work.

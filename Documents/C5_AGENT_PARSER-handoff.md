# C5 Agent Parser Handoff

## Completed
- Implemented `AgentParser` for `.claude/agents/*.md` files with:
  - optional YAML frontmatter detection using `---` fences
  - typed extraction for `name`, `description`, and `tools`
  - unknown frontmatter field preservation
  - exact prompt body preservation after frontmatter split
- Added parse-time diagnostics for:
  - missing closing frontmatter fence
  - malformed frontmatter lines
  - non-object top-level frontmatter
  - known-key type mismatches

## Files added
- `ClaudeConfigManager/Infrastructure/Parsers/AgentParser.swift`
- `ClaudeConfigManagerTests/Parsers/AgentParserTests.swift`
- `Documents/C5_AGENT_PARSER-handoff.md`

## Files updated
- `ClaudeConfigManager/Infrastructure/Parsers/SettingsParser.swift`
  - added `SourceRange`
  - added parser issue codes for frontmatter diagnostics
  - extended `SyntaxIssue` with optional `range`
- `ClaudeConfigManager.xcodeproj/project.pbxproj`
  - added new parser/test files to source groups and build phases

## Verification
- Ran:
  - `xcodebuild -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager -configuration Debug -derivedDataPath .derivedData test CODE_SIGNING_ALLOWED=NO`
- Result: `** TEST SUCCEEDED **`

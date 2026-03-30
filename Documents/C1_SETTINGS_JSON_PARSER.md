# Packet C1 - Settings JSON Parser

## Goal
Implement parsing for Claude `settings.json` files into a typed domain model with syntax diagnostics.

## Why this packet exists
Settings resolution depends on a reliable parse layer that understands the documented structure without confusing `settings.json` with `~/.claude.json` responsibilities.

## Inputs
- `Docs/PROJECT_INDEX.md`
- `Docs/Sections/SECTION_C_PARSERS.md`
- discovered settings file references from later discovery output

## Dependencies
- discovery models from Section B should exist or be stubbed enough to supply file references

## Deliverables
- `SettingsParser`
- `ParsedSettingsDocument`
- typed submodels for common structures
- syntax issue reporting
- initial fixture-backed unit tests

## Minimum supported structures
- top-level settings object
- `$schema`
- `apiKeyHelper`
- `autoMemoryDirectory`
- `cleanupPeriodDays`
- `companyAnnouncements`
- `env`
- `attribution`
- `includeCoAuthoredBy`
- `includeGitInstructions`
- `permissions`
- `autoMode`
- `disableAutoMode`
- `useAutoModeDuringPlan`
- `disableDeepLinkRegistration`
- `hooks`
- `allowManagedHooksOnly`
- `allowedHttpHookUrls`
- `httpHookAllowedEnvVars`
- plugin-related settings fields that belong in this file family

## Important constraints
- The parser must not silently treat `~/.claude.json` fields as valid `settings.json` fields
- Unsupported keys may be preserved in a raw map for forward compatibility, but they should be distinguishable from first-class modeled keys
- Parsing should separate syntax failures from later semantic validation

## Suggested Swift types
- `ParsedSettingsDocument`
- `SettingsDocumentValue`
- `ParsedPermissions`
- `ParsedHooks`
- `ParsedAttribution`
- `ParsedEnvMap`
- `SyntaxIssue`
- `IssueSeverity`

## Test fixture guidance
Create fixtures for:
- valid user settings
- valid project settings
- valid local project settings overrides
- valid hooks structure
- invalid JSON
- invalid hooks shape
- permissions shape edge cases
- unknown fields preserved for forward compatibility

## Acceptance criteria
- Valid settings files parse into a typed document model
- Invalid JSON produces clear syntax issues
- Known nested shapes are normalized correctly
- The parser does not perform precedence merging
- The parser does not assign semantic winners or scope policy

## Out of scope
- `~/.claude.json`
- `.mcp.json`
- CLAUDE.md import resolution
- resolver behavior
- rendering canonical JSON back to disk

## Done when
- Resolver packets can consume parsed settings inputs without re-parsing raw JSON
- Fixture-backed tests cover core valid and invalid cases

## Suggested next packet
- `C2_CLAUDE_JSON_PARSER`

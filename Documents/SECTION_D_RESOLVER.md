# Section D - Resolver Engine

## Purpose
Compute the effective Session state from discovered and parsed Claude-related files.

This is the core of the product. The resolver layer determines effective values, winning sources, participating sources, merge methods, and validation notes without persisting a separate truth store.

## Section goals
- Define domain models for resolved values and provenance
- Implement precedence rules for settings, instructions, MCP, agents, and skills
- Produce a deterministic Session projection
- Surface merge behavior and conflicts clearly
- Keep Session as computed, read-only output

## Key design rules
- Resolver logic must be separate from UI concerns
- Precedence rules are explicit and testable
- Different keys may use different merge methods
- Missing sources and invalid sources must be represented, not silently discarded
- Resolver output should be inspectable enough to power Session UI and save previews later

## Resolver families
### Settings resolver
Produces for each key:
- effective value
- winning source
- participating sources
- merge method
- validation issues
- notes

Baseline precedence for `settings.json`-based configuration:
1. Managed
2. Command-line arguments
3. Project local settings
4. Project shared settings
5. User settings

### Instruction resolver
Needs to model load order among:
- managed `CLAUDE.md`
- user `CLAUDE.md`
- project `CLAUDE.md`
- project `.claude/CLAUDE.md`
- imported files via `@path`
- auto-memory index startup slice
- available on-demand memory topic files

### MCP resolver
Needs to model precedence among:
- local-scoped MCP in `~/.claude.json`
- project `.mcp.json`
- user-scoped MCP in `~/.claude.json`
- managed MCP

### Agent resolver
Needs to model project-over-user precedence and duplicate-name handling.

### Skill resolver
Needs to model discovery by scope, frontmatter validity, and effective visibility.

### Session projection builder
Combines all resolved outputs into one read-only model used by Session UI.

## Suggested Swift types
- `ResolvedValue<T>`
- `ResolutionSource`
- `ResolutionTrace`
- `MergeMethod`
- `ResolutionIssue`
- `ResolvedSettingsSnapshot`
- `ResolvedInstructionSnapshot`
- `ResolvedMcpSnapshot`
- `ResolvedAgentSnapshot`
- `ResolvedSkillSnapshot`
- `SessionProjection`

## Recommended implementation order
1. Resolver shared models
2. Settings precedence
3. Settings merge rules
4. Instruction resolution
5. MCP resolution
6. Agent and skill resolution
7. Session projection builder
8. Resolver tests and snapshots

## Packets in this section
- `D1_RESOLVER_MODELS`
- likely future packets:
  - `D2_SETTINGS_PRECEDENCE`
  - `D3_SETTINGS_MERGE_RULES`
  - `D4_INSTRUCTION_RESOLUTION`
  - `D5_MCP_RESOLUTION`
  - `D6_AGENT_SKILL_RESOLUTION`
  - `D7_SESSION_PROJECTION`

## Completion condition for Section D
This section is complete enough for Milestone 1 when the app can take discovered, parsed inputs and produce a deterministic, inspectable Session projection with provenance and conflict information.

# Packet B1 - Root Locator

## Goal
Implement the discovery service that determines the effective global Claude root and exposes normalized project root references for downstream scanning.

## Why this packet exists
The app needs a single path-resolution layer that translates user selections and defaults into stable discovery inputs.

## Inputs
- `Docs/PROJECT_INDEX.md`
- `Docs/Sections/SECTION_B_DISCOVERY.md`
- outputs from `A2_APP_SANDBOX_AND_BOOKMARKS` and `A3_GLOBAL_AND_PROJECT_ROOT_PICKERS`

## Dependencies
- `A2_APP_SANDBOX_AND_BOOKMARKS`
- `A3_GLOBAL_AND_PROJECT_ROOT_PICKERS`

## Deliverables
- `RootLocator` service
- root resolution models
- normalization rules for selected folders
- issue reporting for inaccessible or invalid roots

## Responsibilities
### Global root resolution
Determine the effective global Claude root using:
1. user-selected override if valid and accessible
2. default conventional location if no override is active
3. explicit issue states if neither is usable

### Project root normalization
- normalize path identity
- ensure reachable sandbox access
- return stable project root references
- classify access issues without scanning file content

## Suggested Swift types
- `RootLocator`
- `RootResolutionResult`
- `ResolvedGlobalRoot`
- `ResolvedProjectRoot`
- `RootSourceKind`
- `RootAccessStatus`
- `DiscoveryIssue`

## Acceptance criteria
- The service returns a deterministic resolved global root result
- The service can report why a root was chosen
- Project roots are normalized consistently
- Access or path issues are surfaced without crashing the app
- No file parsing happens here

## Out of scope
- recursive project scanning
- file-type classification
- resolver precedence

## Done when
- Later discovery packets can depend on a single, tested source of root truth

## Suggested next packet
- `B2_PROJECT_SCANNER`

# F2 Session Instructions View - Handoff

## Completed
- Implemented read-only Session instructions screen integrated into Session scope with segmented panel switch between Settings and Instructions.
- Added projection-driven instructions UI and adapter/view-model types for:
  - deterministic root load order
  - deterministic resolved instruction entries
  - import relation visibility
  - startup-loaded vs on-demand memory separation
  - diagnostics and partial-resolution visibility
- Added fixture preview wiring so Session preview includes representative instruction data.
- Added view-state unit tests covering simple, nested, cycle/missing diagnostics, memory split, empty, and partial states.

## Files updated
- `ClaudeConfigManager/Features/Session/SessionScopeView.swift`
- `ClaudeConfigManagerTests/Resolver/ResolverModelsTests.swift`

## Validation
- `xcodebuild -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager -configuration Debug -derivedDataPath .derivedData build CODE_SIGNING_ALLOWED=NO` succeeded.
- `xcodebuild -project ClaudeConfigManager.xcodeproj -scheme ClaudeConfigManager -configuration Debug -derivedDataPath .derivedData test CODE_SIGNING_ALLOWED=NO` succeeded.

## Assumptions
- F2 integration should live inside the existing Session feature file to avoid project file/source list churn.
- F2 requires model/view-state test coverage (unit tests) rather than full UI automation at this stage.

## Remaining / next packet
- Remaining Session families are out of scope for F2.
- Recommended next packet: `F3_SESSION_HOOKS_VIEW`.

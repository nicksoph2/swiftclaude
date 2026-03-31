# A2_APP_SANDBOX_AND_BOOKMARKS-handoff

## Completed
- Enabled sandbox entitlement for user-selected folder read/write access.
- Added bookmark infrastructure for security-scoped folder access:
  - bookmark models and error types
  - app-owned persistence (metadata JSON + bookmark blob files)
  - bookmark lifecycle service (`upsert`, `resolve`, `restore-on-launch`, `remove`, `release`).
- Added `NSOpenPanel` folder selector abstraction (UI-independent service).
- Wired launch-time bookmark restoration into app bootstrap (`AppRouter`).
- Added unit tests for bookmark behaviors (valid, missing blob, stale, remove lifecycle).
- Updated Xcode project file to include new sources and tests.

## Key Files
- `ClaudeConfigManager/Infrastructure/Bookmarks/BookmarkModels.swift`
- `ClaudeConfigManager/Infrastructure/Bookmarks/BookmarkPersistence.swift`
- `ClaudeConfigManager/Infrastructure/Bookmarks/BookmarkStore.swift`
- `ClaudeConfigManager/Infrastructure/Bookmarks/FolderSelectionService.swift`
- `ClaudeConfigManager/App/AppRouter.swift`
- `ClaudeConfigManager/Resources/ClaudeConfigManager.entitlements`
- `ClaudeConfigManagerTests/Bookmarks/BookmarkStoreTests.swift`

## Validation
- `xcodebuild ... build` passed.
- `xcodebuild ... test` passed.

## Remaining for Next Agent (A3)
- Build global/project root picker UI using `FolderSelecting` + `BookmarkStore`.
- Define stable project bookmark ID strategy and wire reauthorization actions from bootstrap results.
- Surface `bookmarkResolutionResults` and `bookmarkBootstrapSummary` in onboarding/settings UI.

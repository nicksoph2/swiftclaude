# BOOKMARK-EXPANSION Handoff

## Files Modified

| File | Changes |
|------|---------|
| `ClaudeConfigManager/Infrastructure/Bookmarks/BookmarkModels.swift` | Added `userClaudeJson` and `etcClaudeCodeRoot` cases to `BookmarkKind`; added `userClaudeJsonBookmarkID` and `etcClaudeCodeRootBookmarkID` properties to `GlobalAppState` (defaulting to `nil`); added `userClaudeJson` and `etcClaudeCodeRoot` cases to `RootSelectionArea` with corresponding `id` values |
| `ClaudeConfigManager/Infrastructure/Bookmarks/BookmarkStore.swift` | Added `userClaudeJsonBookmarkID` and `etcClaudeCodeRootBookmarkID` static constants |
| `ClaudeConfigManager/Infrastructure/Discovery/WorkspaceScanner.swift` | Added `managedRuleMarkdown` to `DiscoveredFileKind`; added `managedRulesRoot` and `etcManagedRoot` to `DiscoveredDirectoryKind`; added `etcManagedRootPath` and `managedRulesDirectoryName` constants to `ManagedSettingsLocator`; added `scanManagedRulesDirectory()` for rules/*.md scanning; added `scanEtcManagedScope()` for /etc/claude-code scanning; updated `scanManagedWorkspace()` to merge /etc/claude-code results; updated `scanManagedSettingsScope()` to include rules/ scanning in the primary managed root |
| `ClaudeConfigManager/Infrastructure/Pipeline/ConfigurationPipeline.swift` | Added `managedRuleMarkdown` to the two exhaustive switches on `DiscoveredFileKind` — treated as `.claudeMd` file type, parsed with `ClaudeMdParser` |
| `ClaudeConfigManager/App/AppRouter.swift` | Added `setUserClaudeJson()`, `clearUserClaudeJson()`, `setEtcClaudeCodeRoot()`, `clearEtcClaudeCodeRoot()` to `ProjectRegistry`; added `hasAuthorizedUserClaudeJson` and `hasAuthorizedEtcClaudeCodeRoot` published properties to `RootSelectionViewModel`; added `authorizeUserClaudeJson()`, `clearUserClaudeJsonSelection()`, `authorizeEtcClaudeCodeRoot()`, `clearEtcClaudeCodeRootSelection()` methods to `RootSelectionViewModel`; wired new flags into `refreshFromStores()` |
| `ClaudeConfigManagerTests/Discovery/WorkspaceScannerTests.swift` | Updated `testScanIncludesManagedWorkspaceWithManagedFiles` — changed from exact file-kind array comparison to filter-based assertions that accommodate additional /etc/claude-code entries |

## Files Created

| File | Purpose |
|------|---------|
| `ClaudeConfigManagerTests/Bookmarks/BookmarkExpansionTests.swift` | Tests for new `BookmarkKind` raw values, `GlobalAppState` backward-compatible decoding, `BookmarkStore` ID constants, `ProjectRegistry` set/clear methods for both new bookmark types, `RootSelectionViewModel` authorization flag lifecycle |
| `ClaudeConfigManagerTests/Discovery/EtcManagedScanTests.swift` | Tests for `/etc/claude-code` discovery (present and missing), `rules/*.md` scanning in the primary managed root, new enum raw values, new path constants |

## Key Decisions

1. **`managedRuleMarkdown` files are parsed as CLAUDE.md** — Rule markdown files from `rules/` directories are parsed with `ClaudeMdParser` and mapped to `ConfigFileType.claudeMd`, consistent with how managed CLAUDE.md is handled.

2. **`scanEtcManagedScope` reports canonical files even when root is missing** — When `/etc/claude-code/` doesn't exist, the scanner still emits `managedSettingsJSON` and `managedClaudeMarkdown` entries with `.missing` status, matching the pattern used for the primary managed root.

3. **No separate scan orchestration wiring needed** — `BookmarkStore.restoreAccessToKnownFolders()` already iterates over all stored bookmark records. New bookmarks created via `upsertBookmark` are automatically resolved at bootstrap.

4. **`authorizeUserClaudeJson` uses file selection** — The NSOpenPanel for `~/.claude.json` is configured with `showsHiddenFiles: true` and targets the home directory, since `.claude.json` is a dotfile.

5. **Updated existing test rather than skipping** — `testScanIncludesManagedWorkspaceWithManagedFiles` was updated to use filter-based assertions instead of exact array comparison, since the managed workspace now includes `/etc/claude-code` entries.

## Open Questions

1. **File-level bookmark for `~/.claude.json`** — The `FolderSelecting` protocol and `OpenPanelFolderSelector` are designed for folder selection. The `authorizeUserClaudeJson()` method currently uses the same `selectFolder` API. For a true file-level bookmark, the `NSOpenPanel` should be configured with `canChooseFiles = true` and `canChooseDirectories = false`. This may require extending `FolderSelecting` with a `selectFile()` method, or adding a separate `FileSelecting` protocol. The current implementation works because `upsertBookmark` accepts any URL, but the UI panel may not filter to files correctly.

2. **View integration** — No SwiftUI views were created or updated to expose the new authorize/clear buttons. A follow-up packet should wire `hasAuthorizedUserClaudeJson`, `hasAuthorizedEtcClaudeCodeRoot`, and their corresponding action methods into the appropriate settings/authorization UI.

## XcodeGen Required

After these changes, **`xcodegen generate` must be run from `ClaudeConfigManager/`** to pick up the two new test files:
- `ClaudeConfigManagerTests/Bookmarks/BookmarkExpansionTests.swift`
- `ClaudeConfigManagerTests/Discovery/EtcManagedScanTests.swift`

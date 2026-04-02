# Agent Prompt: Add sandbox access for `~/.claude.json` and `/etc/claude-code/`

## Background

Claude Code resolves all its configuration paths from fixed locations. None of them are relocatable via environment variables or settings. This app must mirror Claude Code's actual resolution behaviour — it reads from the same fixed paths, and uses macOS security-scoped bookmarks to gain sandbox access to each one.

Two paths that Claude Code reads are currently not properly handled by this app:

1. **`~/.claude.json`** — The app knows this file exists (it builds the URL at `WorkspaceScanner.swift` line 754–755 and discovers it as `DiscoveredFileKind.userClaudeJSON`), but the security-scoped bookmark for `~/.claude/` does not grant access to `~/.claude.json` because it is a sibling file, not a child. The app has no mechanism to obtain a bookmark for this file.

2. **`/etc/claude-code/`** — Claude Code reads `managed-settings.json`, `CLAUDE.md`, and `rules/*.md` from this directory on macOS. The app does not reference this path anywhere. It is a complete blind spot.

Read the project's `CLAUDE.md` before starting. Follow all its conventions, especially: do not edit `project.pbxproj`, do not run `xcodegen generate` yourself, and create a handoff doc when finished.

## Deliverable 1: Add a security-scoped bookmark for `~/.claude.json`

The path resolution for `~/.claude.json` is already correct — it must always resolve to `homeDirectory + ".claude.json"`, matching Claude Code. The only problem is that the app has no bookmark granting sandbox access to this file.

### 1a. Add bookmark infrastructure

In `BookmarkModels.swift`:

- Add `case userClaudeJson` to `BookmarkKind`
- Add `var userClaudeJsonBookmarkID: String?` to `GlobalAppState`, defaulting to `nil` so existing persisted state decodes without error

In `BookmarkStore.swift`:

- Add `static let userClaudeJsonBookmarkID = "user-claude-json"`

### 1b. Add registry methods

In `AppRouter.swift`, add to the `ProjectRegistry` section (following the pattern of `setManagedRoot` / `clearManagedRoot` at lines 294–316):

- `setUserClaudeJson(fileURL: URL, now: Date = Date())` — creates a **file-level** bookmark (not directory) via `bookmarkStore.upsertBookmark(id: BookmarkStore.userClaudeJsonBookmarkID, kind: .userClaudeJson, ...)`, then saves `state.userClaudeJsonBookmarkID = BookmarkStore.userClaudeJsonBookmarkID`
- `clearUserClaudeJson()` — sets `state.userClaudeJsonBookmarkID = nil`, removes the bookmark

### 1c. Add UI controls

In `RootSelectionViewModel`, add (following the exact pattern of `authorizeManagedRoot()` at lines 505–525):

- `@Published private(set) var hasAuthorizedUserClaudeJson: Bool` — initialised from whether `state.userClaudeJsonBookmarkID != nil` and the bookmark resolves to `.accessible`
- `authorizeUserClaudeJson()` — opens an `NSOpenPanel` configured for **file selection** (not folder), with `allowedContentTypes` set to allow `.json` files, `initialDirectory` set to `RealHomeDirectory.url`, title "Authorize .claude.json", message "Select the .claude.json file in your home directory to grant read access." Calls `projectRegistry.setUserClaudeJson(fileURL:)` on success.
- `clearUserClaudeJsonSelection()` — calls `projectRegistry.clearUserClaudeJson()`, clears any issue, refreshes state

Wire `hasAuthorizedUserClaudeJson` into `refreshFromStores()` following the existing pattern for `hasAuthorizedManagedRoot`.

### 1d. Wire into scanner

In `WorkspaceScanner.scanUserWorkspace()`, the URL construction at line 754–755 stays exactly as-is:

```swift
let userClaudeJSONURL = RootLocator.normalizedDirectoryURL(
    homeDirectoryProvider().appendingPathComponent(".claude.json", isDirectory: false)
)
```

No change to path resolution. The bookmark is resolved separately during the scan lifecycle — the `BookmarkStore` resolves it and calls `startAccessingSecurityScopedResource()` before the scan runs, just as it does for the global root and managed root bookmarks. Ensure the scan orchestration code (wherever bookmarks are resolved and access is started before `WorkspaceScanner.scan()` is called) also resolves `userClaudeJsonBookmarkID` if present.

## Deliverable 2: Add `/etc/claude-code/` as a scanned managed location

Claude Code reads from `/etc/claude-code/` on all platforms including macOS. The files it looks for there are:

- `managed-settings.json` — same schema as `/Library/Application Support/ClaudeCode/managed-settings.json`
- `CLAUDE.md` — managed instructions
- `rules/*.md` — managed rule files (glob for all `.md` files in a `rules/` subdirectory)

### 2a. Add path constant

In `WorkspaceScanner.swift`, in or alongside `ManagedSettingsLocator`, add:

```swift
static let etcManagedRootPath = "/etc/claude-code"
```

### 2b. Add new discovered kinds

In the `DiscoveredFileKind` enum, add:

- `case managedRuleMarkdown` — for `rules/*.md` files in any managed location

In the `DiscoveredDirectoryKind` enum, add:

- `case managedRulesRoot` — for the `rules/` directory inside a managed root
- `case etcManagedRoot` — for the `/etc/claude-code/` directory itself (to distinguish it from the primary managed root at `/Library/Application Support/ClaudeCode/`)

### 2c. Add bookmark infrastructure

In `BookmarkModels.swift`:

- Add `case etcClaudeCodeRoot` to `BookmarkKind`
- Add `var etcClaudeCodeRootBookmarkID: String?` to `GlobalAppState`, defaulting to `nil`

In `BookmarkStore.swift`:

- Add `static let etcClaudeCodeRootBookmarkID = "etc-claude-code-root"`

### 2d. Add registry methods

In `AppRouter.swift`, add (following the `setManagedRoot` / `clearManagedRoot` pattern):

- `setEtcClaudeCodeRoot(folderURL: URL, now: Date = Date())` — upserts bookmark with `id: BookmarkStore.etcClaudeCodeRootBookmarkID`, `kind: .etcClaudeCodeRoot`, saves to state
- `clearEtcClaudeCodeRoot()` — clears state, removes bookmark

### 2e. Add UI controls

In `RootSelectionViewModel`, add (following `authorizeManagedRoot()` / `clearManagedRootSelection()` pattern):

- `@Published private(set) var hasAuthorizedEtcClaudeCodeRoot: Bool`
- `authorizeEtcClaudeCodeRoot()` — `NSOpenPanel` for folder selection, initial directory `/etc/`, title "Authorize /etc/claude-code", message "Select the claude-code folder in /etc/ to grant read access to system-level managed settings."
- `clearEtcClaudeCodeRootSelection()` — clears state and bookmark

Wire into `refreshFromStores()`.

### 2f. Add discovery scanning

Add a new private method to `WorkspaceScanner`:

```swift
private func scanEtcManagedScope(
    issues: inout [DiscoveryIssue]
) -> (files: [DiscoveredFile], directories: [DiscoveredDirectory])
```

This method should:

1. Construct the root URL from `ManagedSettingsLocator.etcManagedRootPath`
2. Use the managed scope identity (`DiscoveryScopeIdentity.managed()`) — these are managed-scope files, same as `/Library/Application Support/ClaudeCode/`
3. Check for `managed-settings.json` → discovered as `.managedSettingsJSON`
4. Check for `CLAUDE.md` → discovered as `.managedClaudeMarkdown`
5. If a `rules/` subdirectory exists and is readable, enumerate `*.md` files → discovered as `.managedRuleMarkdown`
6. Return discovered files and directories

Call this method from `scanManagedWorkspace()` (around line 672). Merge the results into the managed workspace's files and directories arrays. Files from `/Library/Application Support/ClaudeCode/` should appear first (primary macOS path), followed by `/etc/claude-code/` files.

### 2g. Also scan `rules/` in the primary managed root

For consistency, also add `rules/*.md` scanning to the existing `/Library/Application Support/ClaudeCode/` discovery in `scanManagedSettingsScope()`. Claude Code reads `rules/` from both managed locations.

### 2h. Wire into scan orchestration

Wherever the app resolves bookmarks and starts security-scoped access before calling `WorkspaceScanner.scan()`, also resolve `etcClaudeCodeRootBookmarkID` if present and start access. Ensure access is stopped after the scan completes.

## Constraints

- **Do not** modify `project.pbxproj` or any `.xcodeproj` contents. Create `.swift` files on disk; XcodeGen will pick them up.
- **Do not** run `xcodegen generate`. When finished, stop and ask the user to run it from `ClaudeConfigManager/`.
- **Do not** change the resolution logic for `~/.claude.json`. The path is fixed to `homeDirectory + ".claude.json"`, matching Claude Code. Only the bookmark access mechanism is being added.
- **Do not** add any path override or relocation mechanism. Claude Code does not support relocating any of these paths. This app must match that behaviour.
- **Do not** break existing tests. Run `xcodebuild test` after changes.
- **Do not** rename or remove existing public types or properties.
- All new `GlobalAppState` properties must have defaults so existing persisted JSON decodes without error.
- All new `BookmarkKind` cases need raw `String` values (the enum is `RawRepresentable`).
- Follow existing code style: `@MainActor` on observable classes, `Sendable` on value types, `Equatable` on all models.
- New type names must be unique across the module — grep before creating.
- Write tests for new bookmark and discovery logic in `ClaudeConfigManagerTests/`, following existing fixture and mock patterns.
- Create a handoff doc at `Documents/BOOKMARK-EXPANSION-handoff.md` listing files created/modified, decisions made, and any open questions.

## Files likely to be modified

| File                                                                      | Changes                                                                                                                      |
| ------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `Infrastructure/Bookmarks/BookmarkModels.swift`                           | New `BookmarkKind` cases, new `GlobalAppState` properties                                                                    |
| `Infrastructure/Bookmarks/BookmarkStore.swift`                            | New bookmark ID constants                                                                                                    |
| `Infrastructure/Discovery/WorkspaceScanner.swift`                         | New path constant, new `DiscoveredFileKind`/`DiscoveredDirectoryKind` cases, `/etc/claude-code/` scanning, `rules/` scanning |
| `Infrastructure/Discovery/ManagedFileLocator.swift`                       | Possibly extend to cover `/etc/claude-code/`                                                                                 |
| `App/AppRouter.swift`                                                     | New registry methods, new ViewModel properties and actions                                                                   |
| Scan orchestration code (wherever bookmarks are resolved before scanning) | Resolve new bookmark IDs, start/stop access                                                                                  |

## What success looks like

After these changes:

- The app can read `~/.claude.json` via its own bookmark, independent of the `~/.claude/` bookmark
- The app discovers and displays files from `/etc/claude-code/` alongside `/Library/Application Support/ClaudeCode/`
- Both new locations have bookmark-based UI: authorize button, clear button, status indicator
- All paths are fixed, matching Claude Code's actual resolution — no override mechanisms
- Existing tests pass, new tests cover the additions

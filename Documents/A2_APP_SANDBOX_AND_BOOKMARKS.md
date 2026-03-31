# Packet A2 - App Sandbox and Bookmarks

## Goal
Enable secure access to user-selected folders and persist that access using security-scoped bookmarks.

## Why this packet exists
The app must read and later write real Claude-owned files. On macOS, that requires a sandbox-safe approach for selected folders.

## Inputs
- `Docs/PROJECT_INDEX.md`
- `Docs/Sections/SECTION_A_APP_SHELL.md`
- output from `A1_XCODE_SETUP`

## Dependencies
- `A1_XCODE_SETUP`

## Deliverables
- App Sandbox enabled for the macOS target
- user-selected folder access entitlement configured
- bookmark persistence service
- restore-on-launch behavior for known folders
- error handling for stale or invalid bookmarks

## Suggested Swift types
- `BookmarkStore`
- `BookmarkRecord`
- `BookmarkResolutionResult`
- `BookmarkError`

## Required behavior
- Allow the user to choose folders through a standard macOS panel
- Persist security-scoped bookmarks for:
  - global Claude root folder
  - project root folders
- Resolve bookmarks on app launch
- Detect stale bookmarks and surface a reauthorization path
- Keep bookmark storage in app-owned infrastructure only

## Storage guidance
Bookmark metadata should live in app-owned state, not in Claude configuration files.

Likely storage locations:
- app support JSON metadata
- bookmark blobs stored in a controlled app-owned container location

## Acceptance criteria
- A selected folder remains accessible across launches
- Invalid or stale bookmarks are detected cleanly
- Bookmark code is isolated from UI as much as practical
- No Claude-owned files are modified by this packet

## Out of scope
- discovery of Claude-specific files within the selected folders
- project registry semantics beyond what is needed to attach bookmarks
- resolver logic

## Done when
- The app can securely reopen previously selected folders across launches
- Access failures are represented clearly enough for later onboarding and settings screens

## Suggested next packet
- `A3_GLOBAL_AND_PROJECT_ROOT_PICKERS`

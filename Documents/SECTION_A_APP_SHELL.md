# Section A - App Shell and Project Setup

## Purpose
Define the app shell, project structure, sandbox posture, bookmark handling, and the first user flows for selecting the global Claude settings root and one or more project roots.

This section exists so the app can boot cleanly, obtain access to user-selected folders, and provide a stable navigation structure before deeper parsing and resolution work begins.

## Section goals
- Create a native SwiftUI macOS app shell
- Enable App Sandbox and user-selected folder access
- Define the internal folder and target structure for the Xcode project
- Establish app settings and onboarding flows for root selection
- Support a configurable global settings root folder
- Support a registry of project roots
- Provide a four-scope sidebar: Managed, User, Project, Session

## Key design rules
- Root selection is a discovery feature, not a new Claude configuration source
- The app must not alter precedence rules when the root changes
- The app may store bookmark metadata and UI preferences in app-owned files only
- The app must treat Session as read-only from the start
- App shell work should avoid pulling resolver logic into views prematurely

## Responsibilities in this section
### App container and navigation
- App entry point
- root scene setup
- navigation split view or equivalent macOS-native layout
- persistent sidebar selection
- current project selection model

### App settings and onboarding
- initial launch flow
- selecting the global Claude root folder
- selecting one or more project root folders
- showing missing permissions or invalid folder choices

### Storage for app infrastructure
- security-scoped bookmark metadata
- recent project tracking
- UI metadata such as the last selected project
- no authoritative Claude config content

## Files and concepts covered
- Xcode project and targets
- App Sandbox entitlements
- security-scoped bookmarks
- app-owned global state file
- app settings screen or preferences window

## Suggested Swift types
- `ClaudeConfigManagerApp`
- `AppRouter`
- `SidebarDestination`
- `AppBootstrapState`
- `ProjectRegistry`
- `BookmarkStore`
- `GlobalStateStore`
- `RootSelectionViewModel`

## Interfaces with other sections
- Uses discovery contracts from Section B
- Hosts parser and resolver outputs from Sections C and D
- Must remain independent of file-specific editors until later milestones

## Risks
- Mixing app-owned metadata with authoritative Claude config
- Tying UI flows directly to filesystem assumptions that belong in discovery services
- Overbuilding app settings before discovery and resolver contracts are stable

## Recommended implementation order
1. Xcode project scaffolding
2. App Sandbox and bookmark storage
3. Sidebar shell and root-level routing
4. Global root picker
5. Project picker and registry
6. Stub views for Managed, User, Project, Session

## Packets in this section
- `A1_XCODE_SETUP`
- `A2_APP_SANDBOX_AND_BOOKMARKS`
- `A3_GLOBAL_AND_PROJECT_ROOT_PICKERS`
- likely future packets:
  - `A4_SIDEBAR_AND_ROUTING`
  - `A5_GLOBAL_STATE_STORE`
  - `A6_ONBOARDING_FLOW`

## Completion condition for Section A
This section is complete enough for Milestone 1 when the app can launch, remember folder access, present the four-scope shell, and hand selected roots to the discovery layer without embedding business rules in the UI.

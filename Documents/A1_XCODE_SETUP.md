# Packet A1 - Xcode Setup

## Goal
Create the initial native macOS SwiftUI application project for Claude Config Manager.

## Why this packet exists
The rest of the system depends on a stable app target, predictable folder layout, and a clean baseline for future modules.

## Inputs
- `Docs/PROJECT_INDEX.md`
- `Docs/Sections/SECTION_A_APP_SHELL.md`

## Dependencies
- None

## Deliverables
- Xcode project for a macOS app named `ClaudeConfigManager`
- SwiftUI app entry point
- basic group and folder layout aligned with the module map
- placeholder views for Managed, User, Project, and Session
- buildable target with no resolver logic yet

## Recommended project structure
```text
ClaudeConfigManager/
  App/
  Features/
  Core/
  Infrastructure/
  Resources/
  Tests/
```

A possible internal grouping:
- `App/`
  - app entry point
  - router
  - root navigation
- `Features/`
  - scope views
  - settings shell
- `Core/`
  - domain models
- `Infrastructure/`
  - filesystem, persistence, bookmarks
- `Tests/`
  - unit tests and fixture support

## Requirements
- Use Swift
- Use SwiftUI
- Target macOS only
- Start with App Sandbox intended, even if the entitlement wiring is completed in the next packet
- Avoid adding database dependencies
- Avoid adding third-party frameworks unless there is a clear later justification

## Acceptance criteria
- Project opens and builds in Xcode
- App launches to a shell view
- Sidebar or equivalent top-level navigation shows Managed, User, Project, Session
- The project folder structure is understandable and maps to the planning docs
- No business logic is hidden in view files beyond simple routing state

## Out of scope
- Bookmark access
- root selection
- discovery logic
- parsing logic
- resolver logic
- editing and saving

## Done when
- A clean baseline app target exists
- The app can launch and display stub scope screens
- Future packets can add infrastructure without reshaping the whole project

## Suggested next packet
- `A2_APP_SANDBOX_AND_BOOKMARKS`

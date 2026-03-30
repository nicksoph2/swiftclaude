# Packet A3 - Global and Project Root Pickers

## Goal
Create the user flows and view models for selecting the global Claude settings root and one or more project roots.

## Why this packet exists
The app needs a user-controlled discovery entry point that stays separate from resolver rules. This is the first place the configurable root-folder feature appears in the product.

## Inputs
- `Docs/PROJECT_INDEX.md`
- `Docs/Sections/SECTION_A_APP_SHELL.md`
- output from `A2_APP_SANDBOX_AND_BOOKMARKS`

## Dependencies
- `A1_XCODE_SETUP`
- `A2_APP_SANDBOX_AND_BOOKMARKS`

## Deliverables
- Preferences or settings UI for selecting the global Claude root
- project management UI for adding and removing project roots
- root selection view model(s)
- persistence wiring to bookmark storage and global app state
- basic validation messaging for invalid folder selections

## Required behavior
### Global Claude root
- Default to the conventional user Claude root when appropriate
- Allow the user to override it through folder selection
- Store the selected path as discovery configuration only
- Surface the current source of truth for the chosen root, such as default or overridden

### Project roots
- Allow multiple projects
- Show display name and path
- Remember recent selection
- Prevent duplicate registrations of the same normalized path

## Suggested Swift types
- `RootSelectionViewModel`
- `ProjectRegistry`
- `ProjectRegistration`
- `GlobalStateStore`
- `RootSelectionIssue`

## Acceptance criteria
- The user can set a global Claude root folder
- The user can add at least one project root folder
- The app remembers those selections after relaunch
- Duplicate project roots are handled cleanly
- The UI does not claim these selections change config precedence

## Out of scope
- scanning the folders for files
- parsing file content
- Session resolution

## Done when
- The app can manage the two root-selection flows and hand stable paths to the discovery layer

## Suggested next packet
- `B1_ROOT_LOCATOR`

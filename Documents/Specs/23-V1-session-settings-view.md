# Packet V1: Session Settings View Expansion

## Overview

This packet expands the Session Settings UI so it can inspect the newly supported settings families without embedding resolver logic in the views.

## Recommended sections

- Model
- Permissions
- Hooks Policy
- MCP Policy
- Sandbox
- Plugins and Marketplaces
- Authentication and Helpers
- Memory and CLAUDE.md
- UI and Session Experience
- Worktree

## Important corrections

- do not hard-code stale categories around `alwaysThinkingEnabled`, `defaultShell`, `allowedChannelPlugins`, or `channelsEnabled`
- show provenance and issues as first-class UI concerns

## Acceptance criteria

- populated families are visible and readable
- empty families do not clutter the UI
- winning source and issues are clearly shown

# Packet S4: Plugin and Marketplace Control Settings

## Overview

This packet expands plugin and marketplace parsing to match the current Claude Code marketplace model.

## Required settings

- `enabledPlugins`
- `extraKnownMarketplaces`
- `strictKnownMarketplaces`
- `blockedMarketplaces`
- `pluginTrustMessage`
- `channelsEnabled`
- `allowedChannelPlugins`

## Important corrections

- `strictKnownMarketplaces` is not a boolean
- include current managed-only channel controls `channelsEnabled` and `allowedChannelPlugins`
- treat `pluginConfigs`, `skippedMarketplaces`, and `skippedPlugins` as advanced read-only keys rather than verification-gated follow-up keys
- marketplace source objects should be explicitly typed and should support current source variants such as:
  - github
  - git
  - url
  - npm
  - file
  - directory
  - hostPattern
  - inline/settings-style source when verified

## Deliverables

- typed marketplace source models
- parser support for current plugin settings
- fixtures covering representative marketplace source shapes

## Acceptance criteria

- marketplace and plugin settings parse into explicit structures
- managed-only policy keys remain identifiable for later resolver and validation work

# Packet M3: Managed Tier Resolution and Precedence

## Overview

This packet implements managed settings resolution with the correct current precedence semantics.

The earlier local plan assumed that all managed sources merge together. That is outdated. Current Claude Code behavior treats managed source tiers as mutually exclusive except within the file-based managed tier.

## Correct precedence model

Managed settings resolve in this order:

1. server-managed settings
2. MDM / OS policy
3. file-based managed settings

Only the file-based tier merges internally.

## Deliverables

- `ManagedSettingsResolver`
- representation of active managed source tier
- file-based merge logic for:
  - `managed-settings.json`
  - `managed-settings.d/*.json`
- managed tier wiring into the main settings resolver as highest precedence
- managed MCP participation in the effective MCP state

## Important constraints

- if server-managed settings are present, MDM and file-based settings do not participate
- if MDM is present and server-managed settings are absent, file-based settings do not participate
- only the file-based tier merges internally
- tests must prove this behavior explicitly

## Acceptance criteria

- managed precedence matches the current docs
- Session resolution changes correctly when each managed tier becomes active
- Managed scope can report which tier is in effect

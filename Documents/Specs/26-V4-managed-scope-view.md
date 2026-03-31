# Packet V4: Managed Scope View Full Implementation

## Overview

This packet replaces the placeholder Managed scope with a meaningful managed-policy inspector.

## Deliverables

- status for each managed source tier:
  - server-managed
  - MDM / OS policy
  - file-based managed settings
- display of discovered file-based managed sources and their status
- managed MCP status and summary
- access-denied or entitlement-limited messaging
- display of managed CLAUDE.md content when present at `/Library/Application Support/ClaudeCode/CLAUDE.md`
- managed CLAUDE.md is an instruction source that applies to all Claude Code sessions on the machine
- show presence/absence/inaccessible state for managed CLAUDE.md alongside other managed sources

## Important corrections

- the view should reflect the corrected managed-tier semantics from M3
- it should show which tier is active, not imply that all managed tiers merge together

## Acceptance criteria

- users can tell whether managed policy is active, absent, or inaccessible
- the active managed source tier is explicit
- managed MCP presence is visible
- managed CLAUDE.md presence is visible in the Managed scope view
- inaccessible managed CLAUDE.md produces an explicit state, not silent omission

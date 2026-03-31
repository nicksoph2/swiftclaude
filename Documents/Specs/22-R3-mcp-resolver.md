# Packet R3: MCP Resolver Updates

## Overview

This packet resolves MCP servers and MCP policy controls into a trustworthy effective MCP snapshot.

## Deliverables

- integration of user, project/local, and managed MCP sources
- enforcement of:
  - `allowManagedMcpServersOnly`
  - `enableAllProjectMcpServers`
  - `enabledMcpjsonServers`
  - `disabledMcpjsonServers`
  - `allowedMcpServers`
  - `deniedMcpServers`
- server-level provenance and effective-state explanation

## Important guidance

- keep transport modeling aligned with the updated P3 MCP spec, not old speculative transport assumptions
- deny rules should win where current docs indicate they do
- managed MCP visibility and non-overridability should be explicit

## Acceptance criteria

- effective MCP state explains why each server is active, disabled, blocked, or managed
- tests cover allow/deny restrictions and managed-only gating

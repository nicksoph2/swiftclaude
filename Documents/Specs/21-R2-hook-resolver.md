# Packet R2: Hook Resolver Updates

## Overview

This packet resolves the modern hook surface into an effective Session hook snapshot with provenance and policy effects.

## Deliverables

- resolution for the current hook event catalog from H1
- resolution for current hook handler types from H2:
  - command
  - http
  - prompt
  - agent
- policy handling for:
  - `disableAllHooks`
  - `allowManagedHooksOnly`
- event/handler-level provenance

## Important corrections

- do not model hook resolver transports as `sse` or `streamableHttp`
- do not retain the old “23 event types” framing

## Acceptance criteria

- resolved hooks reflect the current event set and handler types
- policy suppression is visible and attributable
- tests prove managed-level hook policy effects

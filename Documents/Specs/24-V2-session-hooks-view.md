# Packet V2: Session Hooks View Expansion

## Overview

This packet updates the Session Hooks UI to match the current hook model.
pleae check first if this work has already been done if it has stop and report

## Deliverables

- grouped display of the current hook event catalog
- handler display for:
  - command
  - http
  - prompt
  - agent
- matcher details
- conditional and async indicators when present
- global-policy banners for `disableAllHooks` and managed-only restrictions

## Important corrections

- do not show stale hook transport labels like `sse` or `streamableHttp`
- do not anchor the view to the older 23-event taxonomy

## Acceptance criteria

- current hook events render cleanly
- handler-specific fields are understandable
- policy effects are visible, not implicit

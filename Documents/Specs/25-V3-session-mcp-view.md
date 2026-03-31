# Packet V3: Session MCP View Expansion

## Overview

This packet upgrades the Session MCP view so it explains the effective MCP state rather than only listing servers.

## Deliverables

- server list with effective status
- transport details from the normalized MCP model
- policy visibility for allow/deny restrictions and managed-only gating
- provenance for each server definition

## Acceptance criteria

- the view makes it clear why a server is active, disabled, blocked, or managed
- managed MCP servers are visually distinct
- policy banners appear when managed-only restrictions are active

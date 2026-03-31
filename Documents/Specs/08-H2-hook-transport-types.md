# Packet H2: Hook Handler Types

## Overview

This packet expands hooks beyond command-only parsing and aligns the parser with the current Claude Code hook handler model.

## Supported handler types

- `command`
- `http`
- `prompt`
- `agent`

## Important corrections

- do not model hook transports as `sse` or `streamableHttp`; those are MCP concerns, not current hook handler types
- do not invent HTTP method/body fields unless the current implementation work verifies them from current sources

## Deliverables

- explicit hook handler enum or normalized model
- per-handler field parsing and validation
- support for common fields like timeout and status message where applicable
- fixtures covering all four handler types

## Acceptance criteria

- each current handler type parses correctly
- missing required fields produce clear issues
- mixed handler fixtures parse without regressions

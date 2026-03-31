# Packet E4: Schema Validation for Expanded Settings Coverage

## Overview

This packet adds schema validation for the expanded parser and resolver surface.

## Validation scope

Validate:

- enum values
- number ranges
- nested object shapes
- managed-only scope restrictions
- hook property compatibility
- MCP restriction rule shapes
- plugin marketplace source shapes
- sandbox nested families

## Important corrections

- do not validate against stale settings families unless they were intentionally kept after re-verification
- do not assume hook transports like `sse` or `streamableHttp`
- do not treat `strictKnownMarketplaces` as a boolean
- do not treat MCP allow/deny controls as string arrays

## Acceptance criteria

- invalid current shapes produce attributable issues
- valid current fixtures produce no false positives
- unknown keys remain forward-compatible warnings or infos, not hard schema failures

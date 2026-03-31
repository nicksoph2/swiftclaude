# Packet R1: Settings Resolver for Expanded Key Families

## Overview

This packet wires the expanded settings surface through the resolver so Session can display effective values with provenance and correct precedence.

## Deliverables

- resolver support for the new settings families introduced by G1/G2, P1/P2, S1-S4, U1/U2, and managed-tier packets
- explicit merge behavior per family
- managed precedence at the very top
- provenance and issue output suitable for Session UI

## Important corrections

- managed settings are above command-line arguments
- managed source tiers must follow the corrected M3 semantics
- include currently documented settings families like `alwaysThinkingEnabled`, `defaultShell`, `allowedChannelPlugins`, and `channelsEnabled`
- keep speculative keys verification-gated instead of silently omitting documented keys
- do not assume all arrays use append semantics; follow current docs family by family

## Acceptance criteria

- resolver behavior is explicit and test-backed for scalar, object, array, and managed-only policy keys
- managed policy can make lower-scope values ineffective and provenance should explain that

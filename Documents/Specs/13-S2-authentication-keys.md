# Packet S2: Authentication and Identity Keys

## Overview

This packet adds currently verifiable authentication and helper-script settings rather than carrying forward stale assumptions.

## Prioritized settings

- `forceLoginMethod`
- `forceLoginOrgUUID`
- `otelHeadersHelper`
- existing `apiKeyHelper` support must remain correct

Include helper-script settings where verified during implementation:

- `awsAuthRefresh`
- `awsCredentialExport`

## Important corrections

- `defaultShell` is currently documented, but it belongs in terminal/input behavior work rather than authentication parsing

## Deliverables

- parser support for the listed keys
- UUID-shape validation for `forceLoginOrgUUID`
- fixtures for valid and invalid cases

## Acceptance criteria

- verified authentication/helper keys parse correctly
- invalid UUID values produce warnings
- no misplaced `defaultShell` requirement remains in this spec

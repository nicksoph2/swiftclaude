# Packet G2: Typed Accessor Layer for SettingsDocumentValue

## Overview

This packet adds typed accessors on top of the registry-backed settings store introduced in G1. The goal is to let resolver, validation, and UI code consume the expanded settings surface without growing `SettingsDocumentValue` into an unmaintainable pile of one-off properties.

Existing named properties already used by the codebase must continue to work.

## Deliverables

### 1. Registry-backed storage in `SettingsDocumentValue`

Add internal keyed storage for parsed settings values while preserving all existing public fields that downstream code already uses.

The keyed store should hold:

- all recognized top-level settings
- preserved unsupported keys
- nested JSON values for complex families

### 2. Typed accessor API

Add a new extension file for:

- `string(for:)`
- `bool(for:)`
- `int(for:)`
- `number(for:)`
- `stringArray(for:)`
- `object(for:)`
- `jsonValue(for:)`

Also add grouped accessors for:

- model settings
- permission settings
- hook policy settings
- MCP settings
- sandbox settings
- plugin and marketplace settings
- authentication and helper settings
- UI/session settings
- worktree settings
- memory and CLAUDE.md settings

### 3. Design constraints

- wrong-type access should return nil, not throw
- absent keys should return nil
- grouped accessors should return empty dictionaries when nothing is configured
- do not add stale or speculative convenience properties for deprecated or unverified keys

## Acceptance criteria

- existing code using current named properties still works unchanged
- accessors correctly expose newly supported keys from the registry-backed store
- tests cover scalar, array, object, and category-based access

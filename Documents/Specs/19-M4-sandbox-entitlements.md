# Packet M4: Sandbox Entitlements and Managed Access Fallback

## Overview

This packet handles the macOS sandbox implications of reading managed Claude Code configuration under `/Library/Application Support/ClaudeCode/`.

## Deliverables

- entitlement update for App Store-safe read-only folder access
- fallback UX when sandbox access is denied or unavailable
- managed-scope messaging that explains the limitation clearly

## Important corrections

- align terminology with the corrected managed packets:
  - M1 is managed discovery
  - M2 is MDM policy reading
  - M3 is managed-tier resolution and precedence
- do not describe M2 or M3 using stale names
- prefer `com.apple.security.files.user-selected.read-only` and security-scoped bookmarks for user-configurable folders
- do not add any privileged helper, installer, or admin-write path to inspect managed settings
- file-based managed settings under `/Library/Application Support/ClaudeCode/` may be unreadable in a sandboxed App Store build; that must become explicit UX, not a hidden failure

## Acceptance criteria

- the app either reads managed paths successfully or explains why it cannot
- user/project bookmark flows remain unaffected
- managed access failures never become silent omissions

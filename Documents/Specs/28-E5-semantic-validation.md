# Packet E5: Semantic Validation for New Interactions

## Overview

This packet adds cross-key and cross-scope validation after schema validation is complete.

## Target interactions

- hooks defined but neutralized by `disableAllHooks`
- lower-scope hooks or MCP settings made ineffective by managed-only policy
- contradictory allow/deny combinations
- contradictory sandbox policies
- MCP entries blocked by deny rules or managed-only restrictions
- plugin marketplace settings that are ineffective because of higher-precedence managed policy

## Important corrections

- semantic messaging about managed precedence must follow the corrected managed model from M3
- do not describe project settings as overriding managed settings; managed settings are highest precedence

## Acceptance criteria

- semantic issues explain real user-facing consequences of policy and precedence
- rules avoid false positives on valid configurations

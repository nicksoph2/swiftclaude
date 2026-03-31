# Packet H1: Current Hook Event Catalog

## Overview

This packet updates hook parsing to the current Claude Code hook event model. The older local assumption of a fixed 23-event lifecycle is outdated and should no longer guide implementation.

The parser should move from ad hoc string keys toward a typed hook event representation while preserving forward compatibility for unknown future events.

## Current event coverage target

Model the currently documented event family, including:

- `SessionStart`
- `SessionEnd`
- `UserPromptSubmit`
- `PreToolUse`
- `PostToolUse`
- `PostToolUseFailure`
- `PermissionRequest`
- `Notification`
- `Stop`
- `StopFailure`
- `SubagentStart`
- `SubagentStop`
- `PreCompact`
- `PostCompact`
- `InstructionsLoaded`
- `ConfigChange`
- `WorktreeCreate`
- `WorktreeRemove`
- `Elicitation`
- `ElicitationResult`
- `CwdChanged`
- `FileChanged`
- `TaskCreated`
- `TaskCompleted`
- `TeammateIdle`

`Setup` may be retained as schema-backed forward compatibility if the implementation finds it already referenced in current repo materials.

## Event behavioral semantics

Each hook event has behavioral capabilities that the app should surface in UI. These are NOT configuration options — they are inherent properties of each event type:

### Blocking events
Events marked as blocking can prevent Claude Code from proceeding. When a hook handler returns a non-zero exit code (command), an error response (http), or an error result (prompt/agent), Claude Code will stop the action that triggered the hook.

Blocking events: `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `PermissionRequest`, `Stop`, `SubagentStop`, `ConfigChange`, `WorktreeCreate`, `Elicitation`, `ElicitationResult`, `TaskCreated`, `TaskCompleted`, `TeammateIdle`

### Context injection events
Some blocking events can inject content into Claude's context when the hook succeeds. The hook's stdout (command) or response body (http) or result text (prompt/agent) is added to the conversation context.

Context injection events: `UserPromptSubmit` (modifies/augments the user's prompt), `PreToolUse` (can modify tool parameters), `PostToolUse` (can annotate tool results), `Stop` (can provide continuation instructions)

### Prompt erasure
`UserPromptSubmit` hooks have a special capability: if the hook returns a `{ "result": "block" }` response, the user's prompt is completely erased from the conversation — it is never sent to the model.

### UI surfacing
The app should display these behavioral capabilities as metadata alongside each hook event in the Session hooks view:
- A "Blocking" badge on events that can block
- A "Context injection" badge on events that can inject context
- A "Prompt erasure" note on UserPromptSubmit specifically
- These badges help administrators understand the security implications of hooks at each event point

## Deliverables

- `HookEventType` enum or equivalent typed representation
- support for unknown event names as preserved-but-warned entries
- parser updates so hooks are no longer treated as arbitrary strings only
- fixtures covering representative current events

## Important constraints

- remove reliance on speculative old events like `PreEdit`, `PostBash`, `PreWebFetch`, or similar unless the implementation can verify that the app intentionally still wants to preserve them as unknown future-compatible strings rather than as first-class enum cases
- unknown events should warn, not hard-fail

## Acceptance criteria

- current documented event names parse into typed cases
- unknown event names are preserved with warnings
- existing hook parsing behavior does not regress for currently supported examples

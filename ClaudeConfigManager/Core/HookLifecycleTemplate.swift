import Foundation

/// Defines the canonical session lifecycle event sequence for the Hooks stage.
///
/// This template provides the "skeleton" timeline that actual hook
/// configurations are merged onto in Stage 6 (Hooks Lifecycle).
enum HookLifecycleTemplate {

    /// A single canonical lifecycle event in the session timeline.
    struct Event: Identifiable, Sendable {
        let eventKey: String
        let displayName: String
        let isRepeating: Bool
        let description: String

        var id: String { eventKey }
    }

    /// The ordered sequence of lifecycle events in a Claude Code session.
    ///
    /// Events marked `isRepeating` occur inside the user-turn loop and
    /// may fire multiple times per session.
    static let events: [Event] = [
        Event(
            eventKey: "SessionStart",
            displayName: "Session Start",
            isRepeating: false,
            description: "Fires once when a new Claude Code session begins."
        ),
        Event(
            eventKey: "Setup",
            displayName: "Setup",
            isRepeating: false,
            description: "Fires after session initialization completes and before the first user prompt."
        ),
        Event(
            eventKey: "UserPromptSubmit",
            displayName: "User Prompt Submit",
            isRepeating: true,
            description: "Fires each time the user submits a new prompt."
        ),
        Event(
            eventKey: "PreToolUse",
            displayName: "Pre Tool Use",
            isRepeating: true,
            description: "Fires before each tool invocation, allowing inspection or rejection."
        ),
        Event(
            eventKey: "PostToolUse",
            displayName: "Post Tool Use",
            isRepeating: true,
            description: "Fires after each tool invocation completes, with the result."
        ),
        Event(
            eventKey: "Notification",
            displayName: "Notification",
            isRepeating: true,
            description: "Fires when Claude Code emits a user-visible notification."
        ),
        Event(
            eventKey: "Stop",
            displayName: "Stop",
            isRepeating: true,
            description: "Fires when the assistant turn ends (response complete)."
        ),
        Event(
            eventKey: "SubagentStart",
            displayName: "Sub-agent Start",
            isRepeating: true,
            description: "Fires when a sub-agent is spawned."
        ),
        Event(
            eventKey: "SubagentStop",
            displayName: "Sub-agent Stop",
            isRepeating: true,
            description: "Fires when a sub-agent completes."
        ),
        Event(
            eventKey: "SessionEnd",
            displayName: "Session End",
            isRepeating: false,
            description: "Fires once when the session is torn down."
        ),
    ]
}

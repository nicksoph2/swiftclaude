import Foundation

/// Static catalog of the built-in tools available in every Claude Code session.
///
/// This is the source of truth for Stage 7 (MCP Servers / Tool Landscape).
enum BuiltInToolCatalog {

    /// A single built-in tool entry.
    struct Tool: Identifiable, Sendable {
        let name: String
        let description: String

        var id: String { name }
    }

    /// The complete list of built-in tools shipped with Claude Code.
    static let tools: [Tool] = [
        Tool(name: "Read", description: "Read file contents from disk"),
        Tool(name: "Write", description: "Write content to a file, creating or overwriting"),
        Tool(name: "Edit", description: "Apply targeted edits to an existing file"),
        Tool(name: "Bash", description: "Execute shell commands in a sandboxed environment"),
        Tool(name: "Glob", description: "Find files matching glob patterns"),
        Tool(name: "Grep", description: "Search file contents with regular expressions"),
        Tool(name: "Agent", description: "Launch a sub-agent for complex multi-step tasks"),
        Tool(name: "WebFetch", description: "Fetch content from a URL"),
        Tool(name: "WebSearch", description: "Search the web for information"),
        Tool(name: "NotebookEdit", description: "Edit Jupyter notebook cells"),
        Tool(name: "TodoWrite", description: "Create and manage a task list"),
        Tool(name: "AskUserQuestion", description: "Ask the user a clarifying question"),
        Tool(name: "ToolSearch", description: "Search for available deferred tools"),
        Tool(name: "Skill", description: "Invoke a registered skill"),
        Tool(name: "ExitPlanMode", description: "Exit plan mode and begin implementation"),
        Tool(name: "SendMessage", description: "Send a message to a running sub-agent"),
        Tool(name: "MultiModelQuery", description: "Query a different model for a second opinion"),
        Tool(name: "RenderPreview", description: "Render a preview of a file or component"),
    ]
}

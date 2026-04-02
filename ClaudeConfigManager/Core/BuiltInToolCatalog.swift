import Foundation

/// Categories for classifying Claude Code tools.
enum ToolCategory: String, Equatable, Sendable, CaseIterable {
    case fileSystem = "File System"
    case shell = "Shell"
    case search = "Search"
    case memory = "Memory"
    case mcp = "MCP"
    case agent = "Agent"
    case other = "Other"
}

/// Static catalog of the built-in tools available in every Claude Code session.
///
/// This is the source of truth for Stage 7 (MCP Servers / Tool Landscape).
enum BuiltInToolCatalog {

    /// A single built-in tool entry.
    struct Tool: Identifiable, Sendable {
        let name: String
        let description: String
        let inputSummary: String
        let category: ToolCategory

        var id: String { name }
    }

    /// The complete list of built-in tools shipped with Claude Code.
    static let tools: [Tool] = [
        Tool(
            name: "Read",
            description: "Read file contents from disk",
            inputSummary: "file_path: string, offset?: number, limit?: number",
            category: .fileSystem
        ),
        Tool(
            name: "Write",
            description: "Write content to a file, creating or overwriting",
            inputSummary: "file_path: string, content: string",
            category: .fileSystem
        ),
        Tool(
            name: "Edit",
            description: "Apply targeted edits to an existing file",
            inputSummary: "file_path: string, old_string: string, new_string: string",
            category: .fileSystem
        ),
        Tool(
            name: "Bash",
            description: "Execute shell commands in a sandboxed environment",
            inputSummary: "command: string, timeout?: number",
            category: .shell
        ),
        Tool(
            name: "Glob",
            description: "Find files matching glob patterns",
            inputSummary: "pattern: string, path?: string",
            category: .search
        ),
        Tool(
            name: "Grep",
            description: "Search file contents with regular expressions",
            inputSummary: "pattern: string, path?: string, glob?: string",
            category: .search
        ),
        Tool(
            name: "Agent",
            description: "Launch a sub-agent for complex multi-step tasks",
            inputSummary: "prompt: string, description: string",
            category: .agent
        ),
        Tool(
            name: "WebFetch",
            description: "Fetch content from a URL",
            inputSummary: "url: string",
            category: .other
        ),
        Tool(
            name: "WebSearch",
            description: "Search the web for information",
            inputSummary: "query: string",
            category: .other
        ),
        Tool(
            name: "NotebookEdit",
            description: "Edit Jupyter notebook cells",
            inputSummary: "notebook_path: string, cell_index: number, new_source: string",
            category: .fileSystem
        ),
        Tool(
            name: "TodoWrite",
            description: "Create and manage a task list",
            inputSummary: "todos: [{content: string, status: string}]",
            category: .memory
        ),
        Tool(
            name: "AskUserQuestion",
            description: "Ask the user a clarifying question",
            inputSummary: "question: string, options?: [string]",
            category: .other
        ),
        Tool(
            name: "ToolSearch",
            description: "Search for available deferred tools",
            inputSummary: "query: string, max_results?: number",
            category: .mcp
        ),
        Tool(
            name: "Skill",
            description: "Invoke a registered skill",
            inputSummary: "skill: string, args?: string",
            category: .other
        ),
        Tool(
            name: "ExitPlanMode",
            description: "Exit plan mode and begin implementation",
            inputSummary: "(no parameters)",
            category: .agent
        ),
        Tool(
            name: "SendMessage",
            description: "Send a message to a running sub-agent",
            inputSummary: "to: string, content: string",
            category: .agent
        ),
        Tool(
            name: "MultiModelQuery",
            description: "Query a different model for a second opinion",
            inputSummary: "model: string, prompt: string",
            category: .agent
        ),
        Tool(
            name: "RenderPreview",
            description: "Render a preview of a file or component",
            inputSummary: "file_path: string",
            category: .other
        ),
    ]

    /// Tools grouped by category, preserving declaration order within each group.
    static var toolsByCategory: [(category: ToolCategory, tools: [Tool])] {
        var grouped: [ToolCategory: [Tool]] = [:]
        for tool in tools {
            grouped[tool.category, default: []].append(tool)
        }
        return ToolCategory.allCases.compactMap { category in
            guard let categoryTools = grouped[category], !categoryTools.isEmpty else { return nil }
            return (category: category, tools: categoryTools)
        }
    }
}

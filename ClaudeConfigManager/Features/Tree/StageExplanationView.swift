import SwiftUI

/// Persistent, collapsible explanation panel for a pipeline stage.
///
/// This view appears at the top of each stage's detail view (when zoomed in from the diagram).
/// The panel renders as a DisclosureGroup with the stage name as the label and the explanation
/// text as content. Default: expanded. On dismissal, the state persists per stage via AppStorage.
struct StageExplanationView: View {
    let stage: PipelineStage

    @AppStorage private var isDismissed: Bool

    init(stage: PipelineStage) {
        self.stage = stage
        // Each stage gets its own AppStorage key
        _isDismissed = AppStorage(wrappedValue: false, "stageExplanationDismissed_\(stage.rawValue)")
    }

    var body: some View {
        DisclosureGroup(isExpanded: .constant(!isDismissed)) {
            Text(explanationText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineSpacing(2)
                .padding(.top, 8)
        } label: {
            HStack {
                Image(systemName: stage.icon)
                    .foregroundStyle(Color.accentColor)
                Text("\(stage.title) Explained")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button(action: { isDismissed = true }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
        .onChange(of: isDismissed) { _, newValue in
            // AppStorage will persist this automatically
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.blue.opacity(0.15), lineWidth: 0.5)
        )
    }

    /// Reset this stage's dismissed state (called from toolbar "Re-read" button)
    func resetDismissed() {
        isDismissed = false
    }

    private var explanationText: String {
        switch stage {
        case .discovery:
            return "Claude Code looks for configuration files in several locations — system-wide managed policy files, your personal `~/.claude` folder, the current project's `.claude` folder, and any session-specific overrides. This stage shows every file it found (or looked for). A missing file is not a problem unless you expected it to be there. Files found here are passed to parsers in the next stage."

        case .parsing:
            return "Each discovered file is read and its contents translated into structured data. A settings file becomes a list of key-value pairs. A CLAUDE.md becomes instruction text with a token count. An `.mcp.json` becomes a list of server definitions. If a file has syntax errors or unexpected field types, they appear here as parse issues. Issues here affect the accuracy of every downstream stage."

        case .resolution:
            return "When the same setting is defined in more than one file, the resolver determines which value 'wins.' The rule is simple: higher scopes beat lower scopes (Managed beats User beats Project). For array settings like permission rules, all scopes' values are combined. This stage shows the winner for every setting and which scopes disagreed. Tap any setting to see its full resolution trace."

        case .promptAssembly:
            return "Before Claude receives your message, a prompt is assembled from several layers: a system prompt describing Claude's role, the tool list (what Claude can do), your CLAUDE.md instruction files stacked in load order, the conversation history, and your current input. Each layer consumes tokens. This stage shows how those tokens are distributed and which instruction files are loaded in what order."

        case .toolExecution:
            return "When Claude wants to use a tool — run a bash command, read a file, call an MCP server — it first passes through a permission gate. Your configured deny, ask, and allow rules are checked in order. The first matching rule wins. This stage shows your actual rules applied to the tool gate so you can see exactly what Claude is allowed to do."

        case .hooksLifecycle:
            return "Hooks are scripts or web requests that fire at specific moments in Claude's session — when a session starts, when a tool is about to run, when Claude finishes a turn. This stage shows the timeline of hook events across a session and which handlers are configured for each event. A hook firing at the wrong time or failing silently can be hard to debug; this view makes the full lifecycle visible."

        case .mcpServers:
            return "Model Context Protocol servers extend Claude's built-in capabilities by providing additional tools. This stage shows the complete landscape of MCP servers in your configuration — which are active, which are blocked by policy, and which tools each server provides. Together with the 18 built-in tools, this determines the total capability set available to Claude in your environment."

        case .contextBudget:
            return "Claude can only 'see' a fixed number of tokens at once — the context window. This stage shows how your assembled prompt uses that budget. A healthy configuration leaves plenty of space for the conversation. A configuration that consumes too much budget with instructions or history will cause Claude to truncate or summarise earlier content, potentially losing important context."
        }
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 16) {
        StageExplanationView(stage: .discovery)
        StageExplanationView(stage: .promptAssembly)
        Spacer()
    }
    .padding()
}
#endif

import SwiftUI

/// A topic entry for the in-app help search system.
struct HelpTopic: Identifiable, Hashable {
    let id: String
    let title: String
    let summary: String
    let keywords: [String]
    let category: HelpCategory
    let destination: SidebarDestination?
    let helpBookPage: String?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: HelpTopic, rhs: HelpTopic) -> Bool { lhs.id == rhs.id }
}

enum HelpCategory: String, CaseIterable {
    case gettingStarted = "Getting Started"
    case scopes = "Scopes"
    case views = "Views"
    case tools = "Tools"
    case settings = "Settings"
    case shortcuts = "Shortcuts"

    var systemImage: String {
        switch self {
        case .gettingStarted: "sparkles"
        case .scopes: "square.stack.3d.up"
        case .views: "rectangle.3.group"
        case .tools: "wrench.and.screwdriver"
        case .settings: "gearshape"
        case .shortcuts: "keyboard"
        }
    }
}

// MARK: - Help Topic Registry

enum HelpTopicRegistry {
    static let allTopics: [HelpTopic] = [
        // Getting Started
        HelpTopic(
            id: "gs-first-launch", title: "First Launch & Setup",
            summary: "Authorise your Claude folder and configure initial settings",
            keywords: ["setup", "authorise", "authorize", "folder", "first", "launch", "start", "onboarding", "root"],
            category: .gettingStarted, destination: .user, helpBookPage: "getting-started.html"
        ),
        HelpTopic(
            id: "gs-add-project", title: "Adding a Project",
            summary: "Register project directories for configuration inspection",
            keywords: ["project", "add", "register", "directory", "folder", "git", "repo"],
            category: .gettingStarted, destination: .project, helpBookPage: "getting-started.html"
        ),
        HelpTopic(
            id: "gs-sidebar", title: "Sidebar Navigation",
            summary: "Navigate between scopes, views, and the dashboard",
            keywords: ["sidebar", "navigation", "menu", "sections", "scope stack"],
            category: .gettingStarted, destination: .dashboard, helpBookPage: "getting-started.html"
        ),

        // Scopes
        HelpTopic(
            id: "scope-precedence", title: "Scope Precedence Order",
            summary: "How Managed > User > Project > Session > CLI layering works",
            keywords: ["precedence", "order", "override", "layer", "priority", "merge", "resolution"],
            category: .scopes, destination: nil, helpBookPage: "scopes.html"
        ),
        HelpTopic(
            id: "scope-managed", title: "Managed Scope",
            summary: "Enterprise MDM policies and server-managed configuration",
            keywords: ["managed", "enterprise", "MDM", "policy", "server", "admin", "locked"],
            category: .scopes, destination: .managed, helpBookPage: "scopes.html"
        ),
        HelpTopic(
            id: "scope-user", title: "User Scope",
            summary: "Global user configuration in ~/.claude",
            keywords: ["user", "global", "home", ".claude", "settings.json", "CLAUDE.md"],
            category: .scopes, destination: .user, helpBookPage: "scopes.html"
        ),
        HelpTopic(
            id: "scope-project", title: "Project Scope",
            summary: "Shared project configuration committed to version control",
            keywords: ["project", "shared", "team", "git", ".claude.json", "committed"],
            category: .scopes, destination: .project, helpBookPage: "scopes.html"
        ),
        HelpTopic(
            id: "scope-project-local", title: "Project-Local Scope",
            summary: "Personal project overrides not committed to git",
            keywords: ["project-local", "local", "personal", ".local", "override", "private"],
            category: .scopes, destination: .projectLocal, helpBookPage: "scopes.html"
        ),
        HelpTopic(
            id: "scope-session", title: "Session Scope",
            summary: "Live session state showing merged resolution",
            keywords: ["session", "live", "active", "running", "merged", "resolved"],
            category: .scopes, destination: .session, helpBookPage: "scopes.html"
        ),
        HelpTopic(
            id: "scope-cli", title: "CLI Scope",
            summary: "Command-line argument overrides",
            keywords: ["CLI", "command", "line", "arguments", "flags", "terminal", "--model"],
            category: .scopes, destination: .cli, helpBookPage: "scopes.html"
        ),

        // Views
        HelpTopic(
            id: "view-dashboard", title: "Dashboard",
            summary: "Configuration health overview with file counts and issue badges",
            keywords: ["dashboard", "overview", "health", "statistics", "summary", "file count"],
            category: .views, destination: .dashboard, helpBookPage: "dashboard.html"
        ),
        HelpTopic(
            id: "view-pipeline", title: "Pipeline View",
            summary: "8-stage visualisation of how Claude Code assembles configuration",
            keywords: ["pipeline", "stages", "discovery", "parsing", "hooks", "MCP", "prompt", "resolution", "tree", "assembly"],
            category: .views, destination: .tree, helpBookPage: "pipeline.html"
        ),
        HelpTopic(
            id: "view-pipeline-simplified", title: "Pipeline: Simplified Mode",
            summary: "Grouped 3-node overview of the pipeline for new users",
            keywords: ["simplified", "mode", "grouped", "overview", "beginner"],
            category: .views, destination: .tree, helpBookPage: "pipeline.html"
        ),
        HelpTopic(
            id: "view-pipeline-advanced", title: "Pipeline: Advanced Mode",
            summary: "Full 8-stage pipeline with individual stage detail",
            keywords: ["advanced", "mode", "detailed", "stages", "expert"],
            category: .views, destination: .tree, helpBookPage: "pipeline.html"
        ),
        HelpTopic(
            id: "view-resolved", title: "Resolved Config",
            summary: "The final merged result of all scopes with provenance tracking",
            keywords: ["resolved", "merged", "final", "output", "result", "provenance", "winning"],
            category: .views, destination: .resolvedConfig, helpBookPage: "resolved-config.html"
        ),
        HelpTopic(
            id: "view-permissions", title: "Permissions Inspector",
            summary: "Rule evaluation order, effective rules, and inheritance tree",
            keywords: ["permissions", "rules", "allow", "deny", "prompt", "inspector", "evaluation"],
            category: .views, destination: .permissions, helpBookPage: "permissions.html"
        ),
        HelpTopic(
            id: "view-issues", title: "Issues",
            summary: "Configuration errors, warnings, and validation diagnostics",
            keywords: ["issues", "errors", "warnings", "validation", "diagnostics", "problems", "syntax"],
            category: .views, destination: .issues, helpBookPage: "issues.html"
        ),
        HelpTopic(
            id: "view-transcripts", title: "Transcripts",
            summary: "Browse and search Claude Code session transcripts",
            keywords: ["transcripts", "sessions", "conversation", "history", "chat", "turns"],
            category: .views, destination: .transcripts, helpBookPage: "transcripts.html"
        ),
        HelpTopic(
            id: "view-analytics", title: "Usage Analytics",
            summary: "Token usage, cost tracking, and trends over time",
            keywords: ["usage", "analytics", "tokens", "cost", "trends", "charts", "graphs"],
            category: .views, destination: .usageAnalytics, helpBookPage: "usage-analytics.html"
        ),

        // Tools
        HelpTopic(
            id: "tool-search", title: "Global Search",
            summary: "Press ⌘F to search across settings, files, servers, and hooks",
            keywords: ["search", "find", "filter", "⌘F", "command-F", "global"],
            category: .tools, destination: nil, helpBookPage: "search.html"
        ),
        HelpTopic(
            id: "tool-whatif", title: "What-If Inspector",
            summary: "Test permission decisions without running Claude Code",
            keywords: ["what-if", "whatif", "test", "simulate", "permission", "tool invocation"],
            category: .tools, destination: .permissions, helpBookPage: "permissions.html"
        ),
        HelpTopic(
            id: "tool-refresh", title: "Refresh Pipeline",
            summary: "Re-scan and re-resolve all configuration (⌘R)",
            keywords: ["refresh", "rescan", "reload", "update", "⌘R"],
            category: .tools, destination: nil, helpBookPage: nil
        ),
        HelpTopic(
            id: "tool-export", title: "Export Transcripts",
            summary: "Save transcripts as JSON or plain text",
            keywords: ["export", "save", "download", "JSON", "text", "transcript"],
            category: .tools, destination: .transcripts, helpBookPage: "transcripts.html"
        ),

        // Settings
        HelpTopic(
            id: "settings-root", title: "Global Root Configuration",
            summary: "Authorise and change your global Claude folder path",
            keywords: ["root", "global", "folder", "path", "authorise", "authorize", "bookmark"],
            category: .settings, destination: .user, helpBookPage: "settings.html"
        ),
        HelpTopic(
            id: "settings-projects", title: "Project Management",
            summary: "Add, remove, and switch between registered projects",
            keywords: ["projects", "manage", "add", "remove", "switch", "register"],
            category: .settings, destination: .project, helpBookPage: "settings.html"
        ),
        HelpTopic(
            id: "settings-schema", title: "Schema Updates",
            summary: "Enable automatic schema fetching for new settings keys",
            keywords: ["schema", "update", "fetch", "remote", "keys", "auto", "refresh"],
            category: .settings, destination: nil, helpBookPage: "settings.html"
        ),

        // Shortcuts
        HelpTopic(
            id: "shortcut-search", title: "⌘F — Open Search",
            summary: "Open the global search overlay",
            keywords: ["⌘F", "command-F", "search", "shortcut"],
            category: .shortcuts, destination: nil, helpBookPage: "shortcuts.html"
        ),
        HelpTopic(
            id: "shortcut-refresh", title: "⌘R — Refresh",
            summary: "Re-scan and re-resolve the pipeline",
            keywords: ["⌘R", "command-R", "refresh", "shortcut"],
            category: .shortcuts, destination: nil, helpBookPage: "shortcuts.html"
        ),
        HelpTopic(
            id: "shortcut-nav", title: "⌘1–5 — Quick Navigation",
            summary: "Jump to Dashboard, Resolved Config, Permissions, Issues, or Pipeline",
            keywords: ["⌘1", "⌘2", "⌘3", "⌘4", "⌘5", "navigation", "shortcut", "jump"],
            category: .shortcuts, destination: nil, helpBookPage: "shortcuts.html"
        ),
    ]
}

// MARK: - Help Search View Model

@MainActor
final class HelpSearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var isPresented: Bool = false
    @Published var selectedTopic: HelpTopic?

    var filteredTopics: [HelpTopic] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return HelpTopicRegistry.allTopics
        }
        let terms = query.lowercased().split(separator: " ").map(String.init)
        return HelpTopicRegistry.allTopics.filter { topic in
            terms.allSatisfy { term in
                topic.title.localizedCaseInsensitiveContains(term)
                || topic.summary.localizedCaseInsensitiveContains(term)
                || topic.keywords.contains(where: { $0.localizedCaseInsensitiveContains(term) })
                || topic.category.rawValue.localizedCaseInsensitiveContains(term)
            }
        }
    }

    /// Predictive suggestions based on partial query input.
    var predictions: [String] {
        guard query.count >= 2 else { return [] }
        let partial = query.lowercased()
        var seen = Set<String>()
        var results: [String] = []

        for topic in HelpTopicRegistry.allTopics {
            // Match keywords that start with the partial query
            for keyword in topic.keywords {
                let lower = keyword.lowercased()
                if lower.hasPrefix(partial) && !seen.contains(lower) {
                    seen.insert(lower)
                    results.append(keyword)
                }
            }
            // Match title words
            for word in topic.title.split(separator: " ") {
                let lower = word.lowercased()
                if lower.hasPrefix(partial) && !seen.contains(lower) {
                    seen.insert(lower)
                    results.append(String(word))
                }
            }
            if results.count >= 5 { break }
        }

        return Array(results.prefix(5))
    }

    func open() {
        query = ""
        selectedTopic = nil
        isPresented = true
    }

    func dismiss() {
        isPresented = false
    }

    func openInHelpBook(_ topic: HelpTopic) {
        guard let page = topic.helpBookPage else { return }
        let anchor = "pages/\(page)"
        NSHelpManager.shared.openHelpAnchor(
            NSHelpManager.AnchorName(anchor),
            inBook: NSHelpManager.BookName("com.example.ClaudeConfigManager.help")
        )
    }
}

// MARK: - Help Search View

struct HelpSearchView: View {
    @ObservedObject var viewModel: HelpSearchViewModel
    var onNavigate: ((SidebarDestination) -> Void)?

    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Search field with predictions
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search help topics…", text: $viewModel.query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($isSearchFocused)
                    .onSubmit {
                        if let first = viewModel.filteredTopics.first {
                            selectTopic(first)
                        }
                    }

                if !viewModel.query.isEmpty {
                    Button {
                        viewModel.query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Predictive text suggestions
            if !viewModel.predictions.isEmpty && !viewModel.query.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(viewModel.predictions, id: \.self) { prediction in
                            Button {
                                viewModel.query = prediction
                            } label: {
                                Text(prediction)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.accentColor.opacity(0.1))
                                    .foregroundStyle(Color.accentColor)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }

            Divider()

            // Results
            if viewModel.filteredTopics.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "questionmark.circle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No matching help topics")
                        .foregroundStyle(.secondary)
                    Text("Try different keywords or browse the full help.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(groupedTopics, id: \.category) { group in
                            Section {
                                ForEach(group.topics) { topic in
                                    helpTopicRow(topic)
                                }
                            } header: {
                                HStack(spacing: 6) {
                                    Image(systemName: group.category.systemImage)
                                        .font(.caption)
                                    Text(group.category.rawValue)
                                        .font(.caption.weight(.semibold))
                                        .textCase(.uppercase)
                                    Spacer()
                                }
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                                .padding(.bottom, 4)
                            }
                        }
                    }
                    .padding(.bottom, 12)
                }
            }
        }
        .frame(width: 520, height: 440)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.2), radius: 20, y: 8)
        .onAppear {
            isSearchFocused = true
        }
    }

    // MARK: - Topic Row

    @ViewBuilder
    private func helpTopicRow(_ topic: HelpTopic) -> some View {
        Button {
            selectTopic(topic)
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(topic.title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(topic.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if topic.destination != nil {
                    Image(systemName: "arrow.right.circle")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                if topic.helpBookPage != nil {
                    Image(systemName: "book")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(viewModel.selectedTopic == topic ? Color.accentColor.opacity(0.1) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 8)
    }

    // MARK: - Grouped Topics

    private struct TopicGroup: Identifiable {
        let category: HelpCategory
        let topics: [HelpTopic]
        var id: String { category.rawValue }
    }

    private var groupedTopics: [TopicGroup] {
        let grouped = Dictionary(grouping: viewModel.filteredTopics, by: \.category)
        return HelpCategory.allCases.compactMap { category in
            guard let topics = grouped[category], !topics.isEmpty else { return nil }
            return TopicGroup(category: category, topics: topics)
        }
    }

    // MARK: - Selection

    private func selectTopic(_ topic: HelpTopic) {
        viewModel.selectedTopic = topic
        if let destination = topic.destination {
            onNavigate?(destination)
            viewModel.dismiss()
        } else if topic.helpBookPage != nil {
            viewModel.openInHelpBook(topic)
            viewModel.dismiss()
        }
    }
}

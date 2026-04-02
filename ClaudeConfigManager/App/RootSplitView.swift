import SwiftUI

struct RootSplitView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var debugMonitor: AppDebugMonitor
    @EnvironmentObject private var rootSelection: RootSelectionViewModel

    @StateObject private var searchViewModel = GlobalSearchViewModel()
    @Namespace private var diagramNamespace

    var body: some View {
        NavigationSplitView {
            ScopeStackSidebar()
                .environmentObject(router)
        } detail: {
            ZStack {
                detailView(for: router.sidebarState.selection ?? .dashboard)
                    .safeAreaInset(edge: .bottom) {
                        #if DEBUG
                        DebugStatusPanel()
                        #endif
                    }

                // Global search overlay
                if searchViewModel.isPresented {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            searchViewModel.dismiss()
                        }

                    GlobalSearchView(
                        viewModel: searchViewModel,
                        onNavigate: { result in
                            navigateToSearchResult(result)
                        }
                    )
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { rootSelection.shouldPromptForInitialGlobalRootAccess },
            set: { newValue in
                if !newValue {
                    rootSelection.skipInitialGlobalRootSetup()
                }
            }
        )) {
            InitialGlobalRootAccessView()
        }
        .onAppear {
            searchViewModel.pipeline = router.pipeline
        }
        // Global keyboard shortcuts
        .keyboardShortcut(for: .search) {
            searchViewModel.open()
        }
        .keyboardShortcut(for: .refresh) {
            router.refreshPipeline()
        }
        .keyboardShortcut(for: .dashboard) {
            router.sidebarState.selection = .dashboard
        }
        .keyboardShortcut(for: .resolvedConfig) {
            router.sidebarState.selection = .resolvedConfig
        }
        .keyboardShortcut(for: .permissions) {
            router.sidebarState.selection = .permissions
        }
        .keyboardShortcut(for: .issues) {
            router.sidebarState.selection = .issues
        }
        .keyboardShortcut(for: .pipelineView) {
            router.sidebarState.selection = .tree
        }
    }

    @ViewBuilder
    private func detailView(for destination: SidebarDestination) -> some View {
        switch destination {
        case .dashboard:
            ConfigurationDashboardView()
        case .tree:
            TreePipelineView()
                .environmentObject(router.pipeline)
        case .permissions:
            PermissionsInspectorView()
        case .managed:
            ManagedScopeView()
        case .user:
            UserScopeView()
        case .project:
            ProjectScopeView()
        case .projectLocal:
            // Project-local reuses ProjectScopeView (filtered) or placeholder
            ProjectScopeView()
        case .session:
            if let projection = router.pipeline.projection {
                SessionScopeView(projection: projection)
            } else {
                SessionScopeView()
            }
        case .cli:
            // CLI scope placeholder
            VStack(spacing: 12) {
                Image(systemName: "terminal")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("CLI Overrides")
                    .font(.title2)
                Text("Command-line argument overrides are not currently active.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .resolvedConfig:
            if let projection = router.pipeline.projection {
                SessionScopeView(projection: projection)
            } else {
                SessionScopeView()
            }
        case .issues:
            IssuesView()
        case .transcripts:
            TranscriptListView()
        case .usageAnalytics:
            UsageAnalyticsDashboardView(
                aggregator: router.usageAggregatorForAnalytics,
                scanner: router.transcriptScannerForAnalytics
            )
        }
    }

    private func navigateToSearchResult(_ result: GlobalSearchResult) {
        // Navigate to the appropriate sidebar destination based on stage
        switch result.stage {
        case .discovery:
            router.sidebarState.selection = .tree
        case .resolution:
            router.sidebarState.selection = .resolvedConfig
        case .mcpServers:
            router.sidebarState.selection = .tree
        case .hooksLifecycle:
            router.sidebarState.selection = .tree
        default:
            router.sidebarState.selection = .tree
        }
    }
}

// MARK: - Scope Stack Sidebar

/// The restructured sidebar with visual scope precedence stack,
/// file count badges, and issue badges.
struct ScopeStackSidebar: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var debugMonitor: AppDebugMonitor

    /// Scope destinations in precedence order (highest first).
    private let scopeDestinations: [SidebarDestination] = [
        .managed, .user, .project, .projectLocal, .session, .cli
    ]

    var body: some View {
        List(selection: $router.sidebarState.selection) {
            // Dashboard (top, not part of scope stack)
            Label(SidebarDestination.dashboard.title, systemImage: SidebarDestination.dashboard.systemImage)
                .tag(SidebarDestination.dashboard)

            // Scope stack section
            Section {
                ForEach(scopeDestinations, id: \.self) { destination in
                    scopeRow(for: destination)
                        .tag(destination)
                }
            } header: {
                HStack {
                    Text("Scope Stack")
                    Spacer()
                    Image(systemName: "arrow.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .help("Higher scopes take precedence")
                }
            }

            // Divider section: Resolved Config
            Section {
                Label(SidebarDestination.resolvedConfig.title, systemImage: SidebarDestination.resolvedConfig.systemImage)
                    .tag(SidebarDestination.resolvedConfig)
                    .fontWeight(.medium)
            } header: {
                Text("Output")
            }

            // Bottom section
            Section {
                Label(SidebarDestination.tree.title, systemImage: SidebarDestination.tree.systemImage)
                    .tag(SidebarDestination.tree)

                Label(SidebarDestination.permissions.title, systemImage: SidebarDestination.permissions.systemImage)
                    .tag(SidebarDestination.permissions)

                issuesRow
                    .tag(SidebarDestination.issues)

                Label(SidebarDestination.transcripts.title, systemImage: SidebarDestination.transcripts.systemImage)
                    .tag(SidebarDestination.transcripts)

                Label(SidebarDestination.usageAnalytics.title, systemImage: SidebarDestination.usageAnalytics.systemImage)
                    .tag(SidebarDestination.usageAnalytics)
            } header: {
                Text("Views")
            }
        }
        .navigationTitle("Claude Config")
        .onAppear {
            debugMonitor.registerSidebar(items: SidebarDestination.allCases)
            debugMonitor.recordSelection(router.sidebarState.selection)
        }
        .onChange(of: router.sidebarState.selection) { _, newValue in
            debugMonitor.recordSelection(newValue)
        }
    }

    // MARK: - Scope Row

    @ViewBuilder
    private func scopeRow(for destination: SidebarDestination) -> some View {
        let fileCount = fileCount(for: destination)
        let issueCount = issueCount(for: destination)
        let isActive = fileCount > 0

        HStack(spacing: 8) {
            // Scope color dot
            if let scope = destination.resolutionScope {
                Circle()
                    .fill(ScopeColorScheme.color(for: scope))
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
            }

            // Scope name
            Text(destination.title)
                .foregroundStyle(isActive ? .primary : .secondary)

            Spacer()

            // File count badge
            if fileCount > 0 {
                Text("\(fileCount) file\(fileCount == 1 ? "" : "s")")
                    .font(.caption2)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.12))
                    .foregroundStyle(.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            } else {
                Text("inactive")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Issue badge
            if issueCount > 0 {
                Text("\(issueCount)")
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.orange.opacity(0.15))
                    .foregroundStyle(.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
        .accessibilityLabel("\(destination.title) scope, \(fileCount) files, \(issueCount) issues")
    }

    // MARK: - Issues Row

    private var issuesRow: some View {
        let errorCount = router.pipeline.semanticIssues.filter { $0.severity == .error }.count
        let warningCount = router.pipeline.semanticIssues.filter { $0.severity == .warning }.count
        let badgeCount = errorCount + warningCount

        return HStack {
            Label(SidebarDestination.issues.title, systemImage: SidebarDestination.issues.systemImage)
            Spacer()
            if badgeCount > 0 {
                Text("\(badgeCount)")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(errorCount > 0 ? .red : .orange)
                    .foregroundStyle(.white)
                    .cornerRadius(3)
            }
        }
    }

    // MARK: - Badge Computation

    private func fileCount(for destination: SidebarDestination) -> Int {
        guard let scanResult = router.pipeline.scanResult else { return 0 }

        switch destination {
        case .managed:
            return scanResult.managedWorkspace?.files.count ?? 0
        case .user:
            return scanResult.userWorkspace?.files.count ?? 0
        case .project:
            let teamFiles = scanResult.projectWorkspaces.flatMap { $0.files }
                .filter { !isProjectLocalFile($0) }
            return teamFiles.count
        case .projectLocal:
            let localFiles = scanResult.projectWorkspaces.flatMap { $0.files }
                .filter { isProjectLocalFile($0) }
            return localFiles.count
        case .session:
            return 0 // Session scope has no on-disk files
        case .cli:
            return 0 // CLI scope has no on-disk files
        default:
            return 0
        }
    }

    private func issueCount(for destination: SidebarDestination) -> Int {
        guard let scope = destination.resolutionScope else { return 0 }

        let scopeRecords = router.pipeline.parseResults.filter { $0.scope == scope }
        let allIssues = scopeRecords.flatMap { $0.parseIssues }
        let significantIssues = allIssues.filter { $0.severity == .warning || $0.severity == .error }
        return significantIssues.count
    }

    private func isProjectLocalFile(_ file: DiscoveredFile) -> Bool {
        file.kind == .projectSettingsLocalJSON
    }
}

// MARK: - Keyboard Shortcut Helpers

/// Identifies a global keyboard shortcut action.
enum GlobalShortcutAction {
    case search       // ⌘F
    case refresh      // ⌘R
    case dashboard    // ⌘1
    case resolvedConfig // ⌘2
    case permissions  // ⌘3
    case issues       // ⌘4
    case pipelineView // ⌘5
}

extension View {
    /// Registers an invisible button that triggers the given action on a keyboard shortcut.
    func keyboardShortcut(for action: GlobalShortcutAction, perform: @escaping () -> Void) -> some View {
        let (key, modifiers) = action.shortcutBinding
        return self.background(
            Button("") { perform() }
                .keyboardShortcut(key, modifiers: modifiers)
                .frame(width: 0, height: 0)
                .opacity(0)
        )
    }
}

extension GlobalShortcutAction {
    var shortcutBinding: (KeyEquivalent, EventModifiers) {
        switch self {
        case .search:        ("f", .command)
        case .refresh:       ("r", .command)
        case .dashboard:     ("1", .command)
        case .resolvedConfig: ("2", .command)
        case .permissions:   ("3", .command)
        case .issues:        ("4", .command)
        case .pipelineView:  ("5", .command)
        }
    }
}

// MARK: - Initial Global Root Access View

private struct InitialGlobalRootAccessView: View {
    @EnvironmentObject private var rootSelection: RootSelectionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Authorize Your Claude Folder", systemImage: "lock.open.display")
                .font(.title2.weight(.semibold))

            Text("To stay App Store compliant, the app only reads global Claude files after you grant folder access. Select the recommended folder below, or choose a different one.")
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Recommended folder")
                    .font(.headline)
                Text(rootSelection.defaultGlobalRootURL.path)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }

            HStack(spacing: 10) {
                Button("Use Recommended Folder") {
                    rootSelection.authorizeRecommendedGlobalRoot()
                }
                .buttonStyle(.borderedProminent)

                Button("Choose Different Folder") {
                    rootSelection.chooseGlobalRootFolder()
                }

                Button("Skip for Now") {
                    rootSelection.skipInitialGlobalRootSetup()
                }
            }

            Text("You can change this later in the User scope sidebar tab.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 620)
    }
}

#if DEBUG
private struct DebugStatusPanel: View {
    @EnvironmentObject private var debugMonitor: AppDebugMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Debug visibility")
                .font(.caption.weight(.semibold))

            Text("Sidebar items: \(debugMonitor.sidebarItems.map(\.title).joined(separator: ", "))")
                .font(.system(.caption, design: .monospaced))

            Text("Selected: \(debugMonitor.selectedDestination?.title ?? "None")")
                .font(.system(.caption, design: .monospaced))

            Text("Main view: \(debugMonitor.detailSnapshot.title)")
                .font(.system(.caption, design: .monospaced))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.thinMaterial)
    }
}
#endif

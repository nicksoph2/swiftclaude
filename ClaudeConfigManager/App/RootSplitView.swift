import SwiftUI

struct RootSplitView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var debugMonitor: AppDebugMonitor
    @EnvironmentObject private var rootSelection: RootSelectionViewModel

    var body: some View {
        NavigationSplitView {
            List(
                SidebarDestination.allCases,
                selection: $router.sidebarState.selection
            ) { destination in
                Label(destination.title, systemImage: destination.systemImage)
                    .tag(destination)
            }
            .navigationTitle("Claude Config")
            .onAppear {
                debugMonitor.registerSidebar(items: SidebarDestination.allCases)
                debugMonitor.recordSelection(router.sidebarState.selection)
            }
            .onChange(of: router.sidebarState.selection) { _, newValue in
                debugMonitor.recordSelection(newValue)
            }
        } detail: {
            detailView(for: router.sidebarState.selection ?? .managed)
                .safeAreaInset(edge: .bottom) {
                    #if DEBUG
                    DebugStatusPanel()
                    #endif
                }
        }
        .sheet(isPresented: .constant(rootSelection.shouldPromptForInitialGlobalRootAccess)) {
            InitialGlobalRootAccessView()
        }
    }

    @ViewBuilder
    private func detailView(for destination: SidebarDestination) -> some View {
        switch destination {
        case .managed:
            ManagedScopeView()
        case .user:
            UserScopeView()
        case .project:
            ProjectScopeView()
        case .session:
            SessionScopeView()
        }
    }
}

private struct InitialGlobalRootAccessView: View {
    @EnvironmentObject private var rootSelection: RootSelectionViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Authorize Your Claude Folder", systemImage: "lock.open.display")
                .font(.title2.weight(.semibold))

            Text("To stay App Store compliant, the app only reads global Claude files after you grant folder access. The recommended folder is preselected when available.")
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

            Text("You can change this later in Settings > Global Root.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 560)
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

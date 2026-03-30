import SwiftUI

@main
struct ClaudeConfigManagerApp: App {
    @StateObject private var router = AppRouter()
    @StateObject private var debugMonitor = AppDebugMonitor()

    var body: some Scene {
        WindowGroup {
            Group {
                switch router.bootstrapState {
                case .launching:
                    ProgressView("Launching Claude Config Manager...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onAppear {
                            router.completeBootstrap()
                        }
                case .ready:
                    RootSplitView()
                }
            }
            .frame(minWidth: 980, minHeight: 620)
            .environmentObject(router)
            .environmentObject(router.rootSelectionViewModel)
            .environmentObject(debugMonitor)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1200, height: 760)

        Settings {
            RootPickerSettingsView()
                .environmentObject(router.rootSelectionViewModel)
                .frame(width: 620, height: 500)
        }
    }
}

private struct RootPickerSettingsView: View {
    var body: some View {
        TabView {
            UserScopeView()
                .tabItem {
                    Label("Global Root", systemImage: "person.crop.circle")
                }

            ProjectScopeView()
                .tabItem {
                    Label("Projects", systemImage: "folder")
                }
        }
        .padding(16)
    }
}

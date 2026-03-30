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
            .environmentObject(debugMonitor)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1200, height: 760)

        Settings {
            Text("Settings will arrive in a later packet.")
                .padding(24)
                .frame(width: 420, height: 180)
        }
    }
}

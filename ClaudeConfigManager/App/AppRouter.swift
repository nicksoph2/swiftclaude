import Foundation

@MainActor
final class AppRouter: ObservableObject {
    @Published private(set) var bootstrapState: AppBootstrapState
    var sidebarState: SidebarState

    init(
        bootstrapState: AppBootstrapState = .launching,
        sidebarState: SidebarState
    ) {
        self.bootstrapState = bootstrapState
        self.sidebarState = sidebarState
    }

    convenience init() {
        self.init(bootstrapState: .launching, sidebarState: SidebarState())
    }

    func completeBootstrap() {
        bootstrapState = .ready

        if sidebarState.selection == nil {
            sidebarState.selection = .managed
        }
    }
}

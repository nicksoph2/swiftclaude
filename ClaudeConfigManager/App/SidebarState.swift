import Foundation

@MainActor
final class SidebarState: ObservableObject {
    @Published var selection: SidebarDestination?

    init(selection: SidebarDestination? = .user) {
        self.selection = selection
    }
}

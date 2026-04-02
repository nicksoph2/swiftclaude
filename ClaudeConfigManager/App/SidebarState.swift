import Foundation

struct SidebarState {
    var selection: SidebarDestination?

    init(selection: SidebarDestination? = .user) {
        self.selection = selection
    }
}

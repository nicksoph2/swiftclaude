import Foundation

struct ScopeScreenModel: Equatable {
    let destination: SidebarDestination
    let title: String
    let subtitle: String

    init(destination: SidebarDestination) {
        self.destination = destination
        self.title = destination.title
        self.subtitle = destination.subtitle
    }
}

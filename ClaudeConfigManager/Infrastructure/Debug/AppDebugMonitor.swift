import Foundation
import os

@MainActor
final class AppDebugMonitor: ObservableObject {
    struct DetailSnapshot: Equatable {
        let title: String
        let subtitle: String
        let debugNotes: [String]
    }

    @Published private(set) var sidebarItems: [SidebarDestination] = []
    @Published private(set) var selectedDestination: SidebarDestination?
    @Published private(set) var detailSnapshot = DetailSnapshot(
        title: "Launching",
        subtitle: "Preparing app shell",
        debugNotes: []
    )

    private let logger = Logger(subsystem: "com.nicholassophocleous.ClaudeConfigManager", category: "AppDebug")

    func registerSidebar(items: [SidebarDestination]) {
        sidebarItems = items
        logger.debug("Sidebar items registered: \(items.map(\.rawValue).joined(separator: ", "))")
    }

    func recordSelection(_ destination: SidebarDestination?) {
        selectedDestination = destination
        logger.debug("Sidebar selection changed: \(destination?.rawValue ?? "nil")")
    }

    func recordDetail(
        title: String,
        subtitle: String,
        debugNotes: [String]
    ) {
        detailSnapshot = DetailSnapshot(title: title, subtitle: subtitle, debugNotes: debugNotes)
        logger.debug("Detail view updated: \(title) | \(subtitle)")
    }
}

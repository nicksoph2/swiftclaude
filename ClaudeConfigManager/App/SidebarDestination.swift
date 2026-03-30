import Foundation

enum SidebarDestination: String, CaseIterable, Codable, Hashable, Identifiable {
    case managed
    case user
    case project
    case session

    var id: String { rawValue }

    var title: String {
        switch self {
        case .managed:
            "Managed"
        case .user:
            "User"
        case .project:
            "Project"
        case .session:
            "Session"
        }
    }

    var subtitle: String {
        switch self {
        case .managed:
            "App-owned metadata and future infrastructure live here."
        case .user:
            "User-scoped Claude files will surface here in later packets."
        case .project:
            "Project-specific Claude configuration will appear here."
        case .session:
            "Resolved session state stays read-only from the start."
        }
    }

    var systemImage: String {
        switch self {
        case .managed:
            "tray.full"
        case .user:
            "person.crop.circle"
        case .project:
            "folder"
        case .session:
            "sparkles.rectangle.stack"
        }
    }
}

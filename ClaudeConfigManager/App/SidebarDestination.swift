import Foundation

enum SidebarDestination: String, CaseIterable, Codable, Hashable, Identifiable {
    case tree
    case managed
    case user
    case project
    case session
    case issues

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tree:
            "Pipeline"
        case .managed:
            "Managed"
        case .user:
            "User"
        case .project:
            "Project"
        case .session:
            "Session"
        case .issues:
            "Issues"
        }
    }

    var subtitle: String {
        switch self {
        case .tree:
            "How Claude Code assembles your configuration"
        case .managed:
            "App-owned metadata and future infrastructure live here."
        case .user:
            "User-scoped Claude files will surface here in later packets."
        case .project:
            "Project-specific Claude configuration will appear here."
        case .session:
            "Resolved session state stays read-only from the start."
        case .issues:
            "Validation issues and configuration problems"
        }
    }

    var systemImage: String {
        switch self {
        case .tree:
            "arrow.triangle.branch"
        case .managed:
            "tray.full"
        case .user:
            "person.crop.circle"
        case .project:
            "folder"
        case .session:
            "sparkles.rectangle.stack"
        case .issues:
            "exclamationmark.triangle"
        }
    }
}

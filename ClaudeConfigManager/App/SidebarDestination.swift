import Foundation

enum SidebarDestination: String, CaseIterable, Codable, Hashable, Identifiable {
    case dashboard
    case tree
    case permissions
    case managed
    case user
    case project
    case session
    case issues

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:
            "Dashboard"
        case .tree:
            "Pipeline"
        case .permissions:
            "Permissions"
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
        case .dashboard:
            "Overview of your Claude configuration health"
        case .tree:
            "How Claude Code assembles your configuration"
        case .permissions:
            "Inspection of permission rules and evaluation order"
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
        case .dashboard:
            "gauge.with.needle"
        case .tree:
            "arrow.triangle.branch"
        case .permissions:
            "lock.open"
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

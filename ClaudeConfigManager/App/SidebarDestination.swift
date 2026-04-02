import Foundation

enum SidebarDestination: String, CaseIterable, Codable, Hashable, Identifiable {
    case dashboard
    case managed
    case user
    case project
    case projectLocal
    case session
    case cli
    case resolvedConfig
    case tree
    case permissions
    case issues
    case transcripts
    case usageAnalytics
    case configGrid
    case flowStrip
    case sessionTimeline

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:
            "Dashboard"
        case .managed:
            "Managed"
        case .user:
            "User"
        case .project:
            "Project"
        case .projectLocal:
            "Project-Local"
        case .session:
            "Session"
        case .cli:
            "CLI"
        case .resolvedConfig:
            "Resolved Config"
        case .tree:
            "Pipeline View"
        case .permissions:
            "Permissions"
        case .issues:
            "Issues"
        case .transcripts:
            "Transcripts"
        case .usageAnalytics:
            "Usage Analytics"
        case .configGrid:
            "Config Grid"
        case .flowStrip:
            "Flow Strip"
        case .sessionTimeline:
            "Session Timeline"
        }
    }

    var subtitle: String {
        switch self {
        case .dashboard:
            "Overview of your Claude configuration health"
        case .managed:
            "App-owned metadata and future infrastructure live here."
        case .user:
            "User-scoped Claude files will surface here in later packets."
        case .project:
            "Project-specific Claude configuration will appear here."
        case .projectLocal:
            "Project-local personal configuration (not committed)."
        case .session:
            "Resolved session state stays read-only from the start."
        case .cli:
            "Command-line argument overrides."
        case .resolvedConfig:
            "The merged result of all scopes after resolution."
        case .tree:
            "How Claude Code assembles your configuration"
        case .permissions:
            "Inspection of permission rules and evaluation order"
        case .issues:
            "Validation issues and configuration problems"
        case .transcripts:
            "Browse and search session transcripts"
        case .usageAnalytics:
            "Token usage, costs, and trends across sessions"
        case .configGrid:
            "Every setting by function, with scope columns and override visibility"
        case .flowStrip:
            "Phase-by-phase view of how config becomes Claude's behaviour"
        case .sessionTimeline:
            "Chronological story of a Claude exchange from config to reply"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard:
            "gauge.with.needle"
        case .managed:
            "tray.full"
        case .user:
            "person.crop.circle"
        case .project:
            "folder"
        case .projectLocal:
            "folder.badge.person.crop"
        case .session:
            "sparkles.rectangle.stack"
        case .cli:
            "terminal"
        case .resolvedConfig:
            "checkmark.seal"
        case .tree:
            "arrow.triangle.branch"
        case .permissions:
            "lock.open"
        case .issues:
            "exclamationmark.triangle"
        case .transcripts:
            "text.bubble"
        case .usageAnalytics:
            "chart.line.uptrend.xyaxis"
        case .configGrid:
            "tablecells"
        case .flowStrip:
            "arrow.down.doc"
        case .sessionTimeline:
            "clock.arrow.2.circlepath"
        }
    }

    /// Whether this destination represents a scope in the precedence stack.
    var isScopeRow: Bool {
        switch self {
        case .managed, .user, .project, .projectLocal, .session, .cli:
            return true
        default:
            return false
        }
    }

    /// The corresponding resolution scope, if this is a scope destination.
    var resolutionScope: ResolutionScope? {
        switch self {
        case .managed:      .managed
        case .user:         .user
        case .project:      .project
        case .projectLocal: .projectLocal
        case .session:      .session
        case .cli:          .cli
        default:            nil
        }
    }
}

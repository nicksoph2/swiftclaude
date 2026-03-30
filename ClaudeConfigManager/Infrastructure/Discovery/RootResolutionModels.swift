import Foundation

enum RootSourceKind: String, Equatable, Sendable {
    case overrideBookmark
    case defaultHomeClaude
    case unresolved
}

enum RootResolutionScope: Equatable, Sendable {
    case globalRoot
    case projectRoot(projectID: String)
}

enum RootAccessStatus: Equatable, Sendable {
    case accessible
    case missing
    case notDirectory
    case inaccessible
    case requiresReauthorization(reason: BookmarkResolutionResult.ReauthorizationReason)

    var isUsableForDiscovery: Bool {
        switch self {
        case .accessible, .missing:
            return true
        case .notDirectory, .inaccessible, .requiresReauthorization:
            return false
        }
    }
}

enum DiscoveryIssueKind: String, Equatable, Sendable {
    case globalOverrideMissingBookmark
    case globalOverrideRequiresReauthorization
    case globalOverrideNotDirectory
    case globalOverrideInaccessible
    case defaultRootNotDirectory
    case defaultRootInaccessible
    case projectMissingBookmark
    case projectRequiresReauthorization
    case projectNotDirectory
    case projectInaccessible
}

struct DiscoveryIssue: Equatable, Identifiable, Sendable {
    let id: String
    let kind: DiscoveryIssueKind
    let scope: RootResolutionScope
    let message: String
    let path: String?

    init(
        kind: DiscoveryIssueKind,
        scope: RootResolutionScope,
        message: String,
        path: String? = nil,
        id: String? = nil
    ) {
        self.kind = kind
        self.scope = scope
        self.message = message
        self.path = path
        self.id = id ?? DiscoveryIssue.makeIdentifier(kind: kind, scope: scope, path: path)
    }

    private static func makeIdentifier(
        kind: DiscoveryIssueKind,
        scope: RootResolutionScope,
        path: String?
    ) -> String {
        let scopeID: String

        switch scope {
        case .globalRoot:
            scopeID = "global"
        case .projectRoot(let projectID):
            scopeID = "project-\(projectID)"
        }

        let pathValue = path ?? "none"
        return "\(kind.rawValue)-\(scopeID)-\(pathValue)"
    }
}

struct ProjectRootReference: Equatable, Identifiable, Sendable {
    let id: String
    let displayName: String
    let preferredPath: String
    let normalizedPath: String
}

struct ResolvedGlobalRoot: Equatable, Sendable {
    let source: RootSourceKind
    let rootURL: URL?
    let normalizedPath: String?
    let accessStatus: RootAccessStatus
    let explanation: String
}

struct ResolvedProjectRoot: Equatable, Sendable {
    let reference: ProjectRootReference
    let rootURL: URL
    let accessStatus: RootAccessStatus
}

struct RootResolutionResult: Equatable, Sendable {
    let globalRoot: ResolvedGlobalRoot
    let projectRoots: [ResolvedProjectRoot]
    let issues: [DiscoveryIssue]
}

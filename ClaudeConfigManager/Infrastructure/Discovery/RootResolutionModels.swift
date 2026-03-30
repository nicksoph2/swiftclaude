import Foundation

enum RootSourceKind: String, Equatable, Sendable {
    case overrideBookmark
    case defaultHomeClaude
    case unresolved
}

enum RootResolutionScope: Equatable, Sendable {
    case globalRoot
    case projectRoot(projectID: String)

    var stableIdentifier: String {
        switch self {
        case .globalRoot:
            return "global"
        case .projectRoot(let projectID):
            return "project-\(projectID)"
        }
    }
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

enum DiscoveryScopeKind: String, Equatable, Sendable {
    case user
    case project
}

struct ProjectScopeIdentity: Equatable, Sendable {
    let projectID: String
    let normalizedProjectRootPath: String
}

struct DiscoveryScopeIdentity: Equatable, Sendable {
    let scopeKind: DiscoveryScopeKind
    let project: ProjectScopeIdentity?
    let sourceDescriptor: String?

    static func user(sourceDescriptor: String? = nil) -> DiscoveryScopeIdentity {
        DiscoveryScopeIdentity(scopeKind: .user, project: nil, sourceDescriptor: sourceDescriptor)
    }

    static func project(projectID: String, normalizedProjectRootPath: String, sourceDescriptor: String? = nil) -> DiscoveryScopeIdentity {
        DiscoveryScopeIdentity(
            scopeKind: .project,
            project: ProjectScopeIdentity(projectID: projectID, normalizedProjectRootPath: normalizedProjectRootPath),
            sourceDescriptor: sourceDescriptor
        )
    }

    var stableIdentifier: String {
        switch scopeKind {
        case .user:
            if let sourceDescriptor {
                return "user::\(sourceDescriptor)"
            }
            return "user"
        case .project:
            let projectID = project?.projectID ?? "unknown"
            if let sourceDescriptor {
                return "project::\(projectID)::\(sourceDescriptor)"
            }
            return "project::\(projectID)"
        }
    }
}

enum DiscoveryNodeClass: String, Equatable, Sendable {
    case file
    case directory
}

struct DiscoveryPathID: Equatable, Hashable, RawRepresentable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(
        normalizedPath: String,
        scope: DiscoveryScopeIdentity,
        nodeClass: DiscoveryNodeClass
    ) {
        let path = RootLocator.normalizedIdentityPath(normalizedPath)
        self.rawValue = "\(nodeClass.rawValue)::\(scope.stableIdentifier)::\(path)"
    }
}

enum DiscoveryPathProvenance: String, Equatable, Sendable {
    case canonicalExpected
    case rootOverrideCanonical
    case descendantDiscovered
}

enum DiscoveryPathStatus: String, Equatable, Sendable {
    case present
    case missing
    case unreadable
    case inaccessible
    case unsupported
}

enum DiscoveryIssueCode: String, Equatable, Sendable {
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
    case scanDirectoryEnumerationFailed
    case scanDescendantInaccessible
}

typealias DiscoveryIssueKind = DiscoveryIssueCode

enum DiscoveryIssueSeverity: String, Equatable, Sendable {
    case info
    case warning
    case error
}

enum DiscoveryIssueTarget: Equatable, Sendable {
    case root(scope: RootResolutionScope, path: String?)
    case workspace(scope: DiscoveryScopeIdentity)
    case file(pathID: DiscoveryPathID)
    case directory(pathID: DiscoveryPathID)
    case scanOperation(scope: DiscoveryScopeIdentity, path: String?)

    var stableIdentifier: String {
        switch self {
        case .root(let scope, let path):
            return "root::\(scope.stableIdentifier)::\(path ?? "none")"
        case .workspace(let scope):
            return "workspace::\(scope.stableIdentifier)"
        case .file(let pathID):
            return "file::\(pathID.rawValue)"
        case .directory(let pathID):
            return "directory::\(pathID.rawValue)"
        case .scanOperation(let scope, let path):
            return "scan::\(scope.stableIdentifier)::\(path ?? "none")"
        }
    }
}

struct DiscoveryIssue: Equatable, Identifiable, Sendable {
    let id: String
    let code: DiscoveryIssueCode
    let severity: DiscoveryIssueSeverity
    let target: DiscoveryIssueTarget
    let message: String
    let path: String?
    let scope: RootResolutionScope?
    let diagnostics: String?

    init(
        kind: DiscoveryIssueKind,
        scope: RootResolutionScope,
        message: String,
        path: String? = nil,
        id: String? = nil
    ) {
        self.code = kind
        self.severity = .warning
        self.target = .root(scope: scope, path: path)
        self.message = message
        self.path = path
        self.scope = scope
        self.diagnostics = nil
        self.id = id ?? DiscoveryIssue.makeIdentifier(code: kind, target: self.target, path: path)
    }

    init(
        code: DiscoveryIssueCode,
        severity: DiscoveryIssueSeverity,
        target: DiscoveryIssueTarget,
        message: String,
        path: String? = nil,
        diagnostics: String? = nil,
        scope: RootResolutionScope? = nil,
        id: String? = nil
    ) {
        self.code = code
        self.severity = severity
        self.target = target
        self.message = message
        self.path = path
        self.scope = scope
        self.diagnostics = diagnostics
        self.id = id ?? DiscoveryIssue.makeIdentifier(code: code, target: target, path: path)
    }

    var kind: DiscoveryIssueKind {
        code
    }

    private static func makeIdentifier(
        code: DiscoveryIssueCode,
        target: DiscoveryIssueTarget,
        path: String?
    ) -> String {
        let pathValue = path ?? "none"
        return "\(code.rawValue)-\(target.stableIdentifier)-\(pathValue)"
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

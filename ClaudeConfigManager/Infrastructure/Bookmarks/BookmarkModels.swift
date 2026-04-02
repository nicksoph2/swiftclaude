import Foundation

enum BookmarkKind: String, Codable, CaseIterable, Sendable {
    case globalClaudeRoot
    case managedClaudeCodeRoot
    case projectRoot
    case userClaudeJson
    case etcClaudeCodeRoot
}

enum GlobalClaudeRootSource: String, Codable, Sendable {
    case defaultHomeClaude
    case overrideBookmark
}

struct BookmarkRecord: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let kind: BookmarkKind
    var displayName: String
    var preferredPath: String
    let createdAt: Date
    var updatedAt: Date

    init(
        id: String,
        kind: BookmarkKind,
        displayName: String,
        preferredPath: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.displayName = displayName
        self.preferredPath = preferredPath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct BookmarkResolutionResult: Equatable, Sendable {
    let record: BookmarkRecord
    let status: Status

    enum Status: Equatable, Sendable {
        case accessible(url: URL)
        case requiresReauthorization(reason: ReauthorizationReason, resolvedURL: URL?)
    }

    enum ReauthorizationReason: Equatable, Sendable {
        case missingBookmarkData
        case invalidBookmarkData
        case staleBookmark
        case accessDenied
    }
}

enum BookmarkError: LocalizedError, Sendable {
    case appSupportLocationUnavailable
    case failedToCreateStorageDirectory
    case failedToLoadMetadata
    case failedToSaveMetadata
    case failedToSaveBookmarkData
    case failedToLoadBookmarkData
    case failedToRemoveBookmarkData
    case failedToCreateBookmark

    var errorDescription: String? {
        switch self {
        case .appSupportLocationUnavailable:
            return "The app support directory could not be resolved."
        case .failedToCreateStorageDirectory:
            return "The bookmark storage folder could not be created."
        case .failedToLoadMetadata:
            return "Bookmark metadata could not be loaded."
        case .failedToSaveMetadata:
            return "Bookmark metadata could not be saved."
        case .failedToSaveBookmarkData:
            return "Bookmark data could not be written to app storage."
        case .failedToLoadBookmarkData:
            return "Bookmark data could not be read from app storage."
        case .failedToRemoveBookmarkData:
            return "Bookmark data could not be removed from app storage."
        case .failedToCreateBookmark:
            return "A security-scoped bookmark could not be created for this folder."
        }
    }
}

struct BookmarkBootstrapSummary: Equatable, Sendable {
    let total: Int
    let accessible: Int
    let requiresReauthorization: Int

    static let empty = BookmarkBootstrapSummary(total: 0, accessible: 0, requiresReauthorization: 0)
}

struct ProjectRegistration: Codable, Equatable, Identifiable, Sendable {
    let id: String
    var displayName: String
    var preferredPath: String
    var normalizedPath: String
    let createdAt: Date
    var updatedAt: Date
}

struct GlobalAppState: Codable, Equatable, Sendable {
    var globalClaudeRootSource: GlobalClaudeRootSource
    var globalClaudeRootBookmarkID: String?
    var hasCompletedInitialGlobalRootSetup: Bool
    var managedRootBookmarkID: String? = nil
    var userClaudeJsonBookmarkID: String? = nil
    var etcClaudeCodeRootBookmarkID: String? = nil
    var projectRegistrations: [ProjectRegistration]
    var selectedProjectRegistrationID: String?

    static let `default` = GlobalAppState(
        globalClaudeRootSource: .defaultHomeClaude,
        globalClaudeRootBookmarkID: nil,
        hasCompletedInitialGlobalRootSetup: false,
        managedRootBookmarkID: nil,
        userClaudeJsonBookmarkID: nil,
        etcClaudeCodeRootBookmarkID: nil,
        projectRegistrations: [],
        selectedProjectRegistrationID: nil
    )
}

enum RootSelectionArea: Equatable, Sendable {
    case globalRoot
    case managedRoot
    case userClaudeJson
    case etcClaudeCodeRoot
    case projects
}

enum RootSelectionIssue: Equatable, Identifiable, Sendable {
    case unreadableGlobalRoot(path: String)
    case recommendedGlobalRootUnavailable(path: String)
    case duplicateProject(path: String)
    case persistenceFailure(area: RootSelectionArea, details: String)
    case bookmarkFailure(area: RootSelectionArea, details: String)

    var id: String {
        switch self {
        case .unreadableGlobalRoot(let path):
            return "unreadable-global-\(path)"
        case .recommendedGlobalRootUnavailable(let path):
            return "recommended-global-unavailable-\(path)"
        case .duplicateProject(let path):
            return "duplicate-project-\(path)"
        case .persistenceFailure(let area, let details):
            return "persistence-\(area.id)-\(details)"
        case .bookmarkFailure(let area, let details):
            return "bookmark-\(area.id)-\(details)"
        }
    }

    var area: RootSelectionArea {
        switch self {
        case .unreadableGlobalRoot, .recommendedGlobalRootUnavailable:
            return .globalRoot
        case .duplicateProject:
            return .projects
        case .persistenceFailure(let area, _):
            return area
        case .bookmarkFailure(let area, _):
            return area
        }
    }

    var message: String {
        switch self {
        case .unreadableGlobalRoot(let path):
            return "The selected folder is not readable: \(path). Choose a readable folder and grant access when prompted."
        case .recommendedGlobalRootUnavailable(let path):
            return "The recommended Claude folder is not currently readable or does not exist: \(path). Choose a different folder or try again later."
        case .duplicateProject(let path):
            return "This project is already registered: \(path)"
        case .persistenceFailure(_, let details):
            return "App state could not be saved. \(details)"
        case .bookmarkFailure(_, let details):
            return "Folder permission could not be saved. \(details)"
        }
    }
}

private extension RootSelectionArea {
    var id: String {
        switch self {
        case .globalRoot:
            return "global-root"
        case .managedRoot:
            return "managed-root"
        case .userClaudeJson:
            return "user-claude-json"
        case .etcClaudeCodeRoot:
            return "etc-claude-code-root"
        case .projects:
            return "projects"
        }
    }
}

import Foundation

protocol RootBookmarkResolving {
    func resolveBookmark(id: String) throws -> BookmarkResolutionResult?
}

extension BookmarkStore: RootBookmarkResolving {}

protocol RootDirectoryAccessChecking {
    func accessStatus(forDirectoryAt url: URL) -> RootAccessStatus
}

struct FileSystemRootDirectoryAccessChecker: RootDirectoryAccessChecking {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func accessStatus(forDirectoryAt url: URL) -> RootAccessStatus {
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)

        guard exists else {
            return .missing
        }

        guard isDirectory.boolValue else {
            return .notDirectory
        }

        return fileManager.isReadableFile(atPath: url.path) ? .accessible : .inaccessible
    }
}

struct RootLocator {
    private let bookmarkResolver: RootBookmarkResolving?
    private let accessChecker: RootDirectoryAccessChecking
    private let homeDirectoryProvider: () -> URL

    init(
        bookmarkResolver: RootBookmarkResolving?,
        accessChecker: RootDirectoryAccessChecking = FileSystemRootDirectoryAccessChecker(),
        homeDirectoryProvider: @escaping () -> URL = { RealHomeDirectory.url }
    ) {
        self.bookmarkResolver = bookmarkResolver
        self.accessChecker = accessChecker
        self.homeDirectoryProvider = homeDirectoryProvider
    }

    func resolveRoots(state: GlobalAppState) -> RootResolutionResult {
        var issues: [DiscoveryIssue] = []
        let defaultRootURL = Self.normalizedDirectoryURL(
            homeDirectoryProvider().appendingPathComponent(".claude", isDirectory: true)
        )

        let globalRoot = resolveGlobalRoot(
            state: state,
            defaultRootURL: defaultRootURL,
            issues: &issues
        )

        let projectRoots = state.projectRegistrations
            .map { resolveProjectRoot($0, issues: &issues) }
            .sorted {
                if $0.reference.normalizedPath == $1.reference.normalizedPath {
                    return $0.reference.id < $1.reference.id
                }
                return $0.reference.normalizedPath < $1.reference.normalizedPath
            }

        let sortedIssues = issues.sorted { lhs, rhs in
            if lhs.id == rhs.id {
                return lhs.message < rhs.message
            }
            return lhs.id < rhs.id
        }

        return RootResolutionResult(
            globalRoot: globalRoot,
            projectRoots: projectRoots,
            issues: sortedIssues
        )
    }

    private func resolveGlobalRoot(
        state: GlobalAppState,
        defaultRootURL: URL,
        issues: inout [DiscoveryIssue]
    ) -> ResolvedGlobalRoot {
        if let bookmarkID = state.globalClaudeRootBookmarkID {
            if let overrideResult = try? bookmarkResolver?.resolveBookmark(id: bookmarkID) {
                switch overrideResult.status {
                case .accessible(let overrideURL):
                    let normalizedOverrideURL = Self.normalizedDirectoryURL(overrideURL)
                    let overrideStatus = accessChecker.accessStatus(forDirectoryAt: normalizedOverrideURL)

                    if overrideStatus.isUsableForDiscovery {
                        return ResolvedGlobalRoot(
                            source: state.globalClaudeRootSource == .defaultHomeClaude ? .defaultHomeClaude : .overrideBookmark,
                            rootURL: normalizedOverrideURL,
                            normalizedPath: Self.normalizedIdentityPath(normalizedOverrideURL.path),
                            accessStatus: overrideStatus,
                            explanation: state.globalClaudeRootSource == .defaultHomeClaude
                                ? "Using the user-authorized default Claude folder."
                                : "Using the user-selected global root folder."
                        )
                    }

                    issues.append(
                        DiscoveryIssue(
                            kind: overrideStatus == .notDirectory ? .globalOverrideNotDirectory : .globalOverrideInaccessible,
                            scope: .globalRoot,
                            message: "The selected global Claude folder is not usable. Reauthorize the folder or choose a different one.",
                            path: normalizedOverrideURL.path
                        )
                    )
                case .requiresReauthorization(let reason, let resolvedURL):
                    issues.append(
                        DiscoveryIssue(
                            kind: .globalOverrideRequiresReauthorization,
                            scope: .globalRoot,
                            message: "The selected global Claude folder needs folder access to be reauthorized.",
                            path: resolvedURL?.path ?? overrideResult.record.preferredPath
                        )
                    )

                    if case .accessDenied = reason {
                        // No additional handling needed; this still falls back to default below.
                    }
                }
            } else {
                issues.append(
                    DiscoveryIssue(
                        kind: .globalOverrideMissingBookmark,
                        scope: .globalRoot,
                        message: "The selected global Claude folder no longer has valid saved access.",
                        path: nil
                    )
                )
            }
        }

        return ResolvedGlobalRoot(
            source: .defaultHomeClaude,
            rootURL: nil,
            normalizedPath: nil,
            accessStatus: .notAuthorized,
            explanation: "Authorize the recommended Claude folder or choose a custom folder to enable global discovery."
        )
    }

    private func resolveProjectRoot(
        _ registration: ProjectRegistration,
        issues: inout [DiscoveryIssue]
    ) -> ResolvedProjectRoot {
        let preferredURL = URL(fileURLWithPath: registration.preferredPath, isDirectory: true)
        let normalizedPreferredURL = Self.normalizedDirectoryURL(preferredURL)

        var resolvedURL = normalizedPreferredURL
        var status: RootAccessStatus = .requiresReauthorization(reason: .missingBookmarkData)

        if let bookmarkResult = try? bookmarkResolver?.resolveBookmark(id: registration.id) {
            switch bookmarkResult.status {
            case .accessible(let bookmarkURL):
                resolvedURL = Self.normalizedDirectoryURL(bookmarkURL)
                status = accessChecker.accessStatus(forDirectoryAt: resolvedURL)
            case .requiresReauthorization(let reason, let resolvedURLFromBookmark):
                status = .requiresReauthorization(reason: reason)
                issues.append(
                    DiscoveryIssue(
                        kind: .projectRequiresReauthorization,
                        scope: .projectRoot(projectID: registration.id),
                        message: "Project root access needs reauthorization before discovery can read this folder reliably.",
                        path: resolvedURLFromBookmark?.path ?? registration.preferredPath
                    )
                )
            }
        } else {
            status = .requiresReauthorization(reason: .missingBookmarkData)
            issues.append(
                DiscoveryIssue(
                    kind: .projectMissingBookmark,
                    scope: .projectRoot(projectID: registration.id),
                    message: "Project root access needs to be granted again before discovery can read this folder.",
                    path: registration.preferredPath
                )
            )
        }

        if !status.isUsableForDiscovery {
            switch status {
            case .notDirectory:
                issues.append(
                    DiscoveryIssue(
                        kind: .projectNotDirectory,
                        scope: .projectRoot(projectID: registration.id),
                        message: "Registered project root path is not a folder.",
                        path: resolvedURL.path
                    )
                )
            case .inaccessible:
                issues.append(
                    DiscoveryIssue(
                        kind: .projectInaccessible,
                        scope: .projectRoot(projectID: registration.id),
                        message: "Registered project root folder is not currently readable.",
                        path: resolvedURL.path
                    )
                )
            case .notAuthorized, .requiresReauthorization, .accessible, .missing:
                break
            }
        }

        return ResolvedProjectRoot(
            reference: ProjectRootReference(
                id: registration.id,
                displayName: registration.displayName,
                preferredPath: registration.preferredPath,
                normalizedPath: Self.normalizedIdentityPath(registration.preferredPath)
            ),
            rootURL: resolvedURL,
            accessStatus: status
        )
    }

    static func normalizedDirectoryURL(_ url: URL) -> URL {
        url.standardizedFileURL.resolvingSymlinksInPath()
    }

    static func normalizedIdentityPath(_ path: String) -> String {
        let resolved = URL(fileURLWithPath: path)
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path

        var normalized = (resolved as NSString).standardizingPath
        if normalized.count > 1, normalized.hasSuffix("/") {
            normalized.removeLast()
        }

        return normalized.lowercased()
    }
}

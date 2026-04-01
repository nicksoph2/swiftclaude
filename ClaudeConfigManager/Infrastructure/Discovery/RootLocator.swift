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
        homeDirectoryProvider: @escaping () -> URL = { FileManager.default.homeDirectoryForCurrentUser }
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
        let defaultStatus = accessChecker.accessStatus(forDirectoryAt: defaultRootURL)

        let wantsOverride = state.globalClaudeRootSource == .overrideBookmark

        if wantsOverride,
           let bookmarkID = state.globalClaudeRootBookmarkID {
            if let overrideResult = try? bookmarkResolver?.resolveBookmark(id: bookmarkID) {
                switch overrideResult.status {
                case .accessible(let overrideURL):
                    let normalizedOverrideURL = Self.normalizedDirectoryURL(overrideURL)
                    let overrideStatus = accessChecker.accessStatus(forDirectoryAt: normalizedOverrideURL)

                    if overrideStatus.isUsableForDiscovery {
                        return ResolvedGlobalRoot(
                            source: .overrideBookmark,
                            rootURL: normalizedOverrideURL,
                            normalizedPath: Self.normalizedIdentityPath(normalizedOverrideURL.path),
                            accessStatus: overrideStatus,
                            explanation: "Using the user-selected global root override bookmark."
                        )
                    }

                    issues.append(
                        DiscoveryIssue(
                            kind: overrideStatus == .notDirectory ? .globalOverrideNotDirectory : .globalOverrideInaccessible,
                            scope: .globalRoot,
                            message: "The selected global root override is not usable. Falling back to the default ~/.claude location when possible.",
                            path: normalizedOverrideURL.path
                        )
                    )
                case .requiresReauthorization(let reason, let resolvedURL):
                    issues.append(
                        DiscoveryIssue(
                            kind: .globalOverrideRequiresReauthorization,
                            scope: .globalRoot,
                            message: "The selected global root override needs folder access to be reauthorized.",
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
                        message: "A global root override is configured but it could not be resolved safely.",
                        path: nil
                    )
                )
            }
        }

        if defaultStatus.isUsableForDiscovery {
            let explanation: String
            if wantsOverride {
                explanation = "Falling back to default ~/.claude because the selected override was unavailable."
            } else {
                explanation = "Using default global root at ~/.claude."
            }

            return ResolvedGlobalRoot(
                source: .defaultHomeClaude,
                rootURL: defaultRootURL,
                normalizedPath: Self.normalizedIdentityPath(defaultRootURL.path),
                accessStatus: defaultStatus,
                explanation: explanation
            )
        }

        issues.append(
            DiscoveryIssue(
                kind: defaultStatus == .notDirectory ? .defaultRootNotDirectory : .defaultRootInaccessible,
                scope: .globalRoot,
                message: "The default global root ~/.claude is not usable.",
                path: defaultRootURL.path
            )
        )

        return ResolvedGlobalRoot(
            source: .unresolved,
            rootURL: nil,
            normalizedPath: nil,
            accessStatus: defaultStatus,
            explanation: "No usable global Claude root was found."
        )
    }

    private func resolveProjectRoot(
        _ registration: ProjectRegistration,
        issues: inout [DiscoveryIssue]
    ) -> ResolvedProjectRoot {
        let preferredURL = URL(fileURLWithPath: registration.preferredPath, isDirectory: true)
        let normalizedPreferredURL = Self.normalizedDirectoryURL(preferredURL)

        var resolvedURL = normalizedPreferredURL
        var status = accessChecker.accessStatus(forDirectoryAt: normalizedPreferredURL)

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
            issues.append(
                DiscoveryIssue(
                    kind: .projectMissingBookmark,
                    scope: .projectRoot(projectID: registration.id),
                    message: "Project root bookmark is missing; using the stored path reference.",
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
            case .requiresReauthorization, .accessible, .missing:
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

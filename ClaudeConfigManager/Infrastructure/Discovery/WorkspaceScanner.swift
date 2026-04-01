import Foundation

typealias DiscoveredPathStatus = DiscoveryPathStatus

enum DiscoveredFileKind: String, Equatable, Sendable {
    case userSettingsJSON
    case userClaudeMarkdown
    case userClaudeJSON
    case userAgentMarkdown
    case userSkillDefinition
    case projectSettingsJSON
    case projectSettingsLocalJSON
    case projectMCPJSON
    case projectClaudeMarkdown
    case projectClaudeDotMarkdown
    case projectAgentMarkdown
    case projectSkillDefinition
}

enum DiscoveredDirectoryKind: String, Equatable, Sendable {
    case userClaudeRoot
    case userAgentsRoot
    case userSkillsRoot
    case userProjectsRoot
    case userProjectMemoryDirectory
    case userSkillDirectory
    case projectRoot
    case projectClaudeDirectory
    case projectAgentsRoot
    case projectSkillsRoot
    case projectSkillDirectory
}

struct DiscoveredFile: Equatable, Identifiable, Sendable {
    let id: DiscoveryPathID
    let scope: DiscoveryScopeIdentity
    let kind: DiscoveredFileKind
    let url: URL
    let normalizedPath: String
    let displayPath: String
    let provenance: DiscoveryPathProvenance
    let status: DiscoveryPathStatus

    init(
        scope: DiscoveryScopeIdentity,
        kind: DiscoveredFileKind,
        url: URL,
        provenance: DiscoveryPathProvenance,
        status: DiscoveryPathStatus
    ) {
        let normalizedURL = RootLocator.normalizedDirectoryURL(url)
        let normalizedPath = RootLocator.normalizedIdentityPath(normalizedURL.path)

        self.scope = scope
        self.kind = kind
        self.url = normalizedURL
        self.normalizedPath = normalizedPath
        self.displayPath = normalizedURL.path
        self.provenance = provenance
        self.status = status
        self.id = DiscoveryPathID(normalizedPath: normalizedPath, scope: scope, nodeClass: .file)
    }
}

struct DiscoveredDirectory: Equatable, Identifiable, Sendable {
    let id: DiscoveryPathID
    let scope: DiscoveryScopeIdentity
    let kind: DiscoveredDirectoryKind
    let url: URL
    let normalizedPath: String
    let displayPath: String
    let provenance: DiscoveryPathProvenance
    let status: DiscoveryPathStatus

    init(
        scope: DiscoveryScopeIdentity,
        kind: DiscoveredDirectoryKind,
        url: URL,
        provenance: DiscoveryPathProvenance,
        status: DiscoveryPathStatus
    ) {
        let normalizedURL = RootLocator.normalizedDirectoryURL(url)
        let normalizedPath = RootLocator.normalizedIdentityPath(normalizedURL.path)

        self.scope = scope
        self.kind = kind
        self.url = normalizedURL
        self.normalizedPath = normalizedPath
        self.displayPath = normalizedURL.path
        self.provenance = provenance
        self.status = status
        self.id = DiscoveryPathID(normalizedPath: normalizedPath, scope: scope, nodeClass: .directory)
    }
}

struct DiscoveredWorkspace: Equatable, Sendable {
    let scope: DiscoveryScopeIdentity
    let rootScope: RootResolutionScope
    let rootURL: URL
    let rootNormalizedPath: String
    let rootAccessStatus: RootAccessStatus
    let files: [DiscoveredFile]
    let directories: [DiscoveredDirectory]
}

struct ScanRequest: Equatable, Sendable {
    let rootResolution: RootResolutionResult
}

struct ScanResult: Equatable, Sendable {
    let userWorkspace: DiscoveredWorkspace?
    let projectWorkspaces: [DiscoveredWorkspace]
    let issues: [DiscoveryIssue]
}

enum WorkspaceScanningNodeKind: Equatable, Sendable {
    case missing
    case file
    case directory
    case inaccessible
}

protocol WorkspaceScanningFileSystem {
    func nodeKind(at url: URL) -> WorkspaceScanningNodeKind
    func isReadable(at url: URL) -> Bool
    func contentsOfDirectory(at url: URL) throws -> [URL]
}

struct FileManagerWorkspaceScanningFileSystem: WorkspaceScanningFileSystem {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func nodeKind(at url: URL) -> WorkspaceScanningNodeKind {
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)

        guard exists else {
            return .missing
        }

        return isDirectory.boolValue ? .directory : .file
    }

    func isReadable(at url: URL) -> Bool {
        fileManager.isReadableFile(atPath: url.path)
    }

    func contentsOfDirectory(at url: URL) throws -> [URL] {
        try fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: []
        )
    }
}

struct WorkspaceScanner {
    private let fileSystem: WorkspaceScanningFileSystem
    private let homeDirectoryProvider: () -> URL

    init(
        fileSystem: WorkspaceScanningFileSystem = FileManagerWorkspaceScanningFileSystem(),
        homeDirectoryProvider: @escaping () -> URL = { FileManager.default.homeDirectoryForCurrentUser }
    ) {
        self.fileSystem = fileSystem
        self.homeDirectoryProvider = homeDirectoryProvider
    }

    func scan(_ request: ScanRequest) -> ScanResult {
        var issues = request.rootResolution.issues

        let userWorkspace = scanUserWorkspace(globalRoot: request.rootResolution.globalRoot, issues: &issues)

        let projectWorkspaces = request.rootResolution.projectRoots
            .map { scanProjectWorkspace(projectRoot: $0, issues: &issues) }
            .sorted {
                if $0.rootNormalizedPath == $1.rootNormalizedPath {
                    return $0.scope.stableIdentifier < $1.scope.stableIdentifier
                }
                return $0.rootNormalizedPath < $1.rootNormalizedPath
            }

        return ScanResult(
            userWorkspace: userWorkspace,
            projectWorkspaces: projectWorkspaces,
            issues: deduplicateAndSortIssues(issues)
        )
    }

    private func scanUserWorkspace(
        globalRoot: ResolvedGlobalRoot,
        issues: inout [DiscoveryIssue]
    ) -> DiscoveredWorkspace? {
        guard let rootURL = globalRoot.rootURL else {
            return nil
        }

        let rootScope = RootResolutionScope.globalRoot
        let scope = DiscoveryScopeIdentity.user(sourceDescriptor: globalRoot.source == .overrideBookmark ? "rootOverride" : nil)
        let canonicalProvenance: DiscoveryPathProvenance = globalRoot.source == .overrideBookmark ? .rootOverrideCanonical : .canonicalExpected

        let normalizedRootURL = RootLocator.normalizedDirectoryURL(rootURL)
        let rootNormalizedPath = RootLocator.normalizedIdentityPath(normalizedRootURL.path)

        var files: [DiscoveredFile] = []
        var directories: [DiscoveredDirectory] = []

        let settingsURL = normalizedRootURL.appendingPathComponent("settings.json", isDirectory: false)
        let userClaudeMarkdownURL = normalizedRootURL.appendingPathComponent("CLAUDE.md", isDirectory: false)
        let userClaudeJSONURL = RootLocator.normalizedDirectoryURL(
            homeDirectoryProvider().appendingPathComponent(".claude.json", isDirectory: false)
        )
        let agentsRootURL = normalizedRootURL.appendingPathComponent("agents", isDirectory: true)
        let skillsRootURL = normalizedRootURL.appendingPathComponent("skills", isDirectory: true)
        let projectsRootURL = normalizedRootURL.appendingPathComponent("projects", isDirectory: true)

        directories.append(discoveredDirectory(scope: scope, kind: .userClaudeRoot, url: normalizedRootURL, provenance: canonicalProvenance))
        directories.append(discoveredDirectory(scope: scope, kind: .userAgentsRoot, url: agentsRootURL, provenance: canonicalProvenance))
        directories.append(discoveredDirectory(scope: scope, kind: .userSkillsRoot, url: skillsRootURL, provenance: canonicalProvenance))
        directories.append(discoveredDirectory(scope: scope, kind: .userProjectsRoot, url: projectsRootURL, provenance: canonicalProvenance))

        files.append(discoveredFile(scope: scope, kind: .userSettingsJSON, url: settingsURL, provenance: canonicalProvenance))
        files.append(discoveredFile(scope: scope, kind: .userClaudeMarkdown, url: userClaudeMarkdownURL, provenance: canonicalProvenance))
        files.append(discoveredFile(scope: scope, kind: .userClaudeJSON, url: userClaudeJSONURL, provenance: .canonicalExpected))

        if globalRoot.accessStatus == .accessible {
            files.append(
                contentsOf: discoverAgentMarkdownFiles(
                    scope: scope,
                    rootScope: rootScope,
                    rootURL: agentsRootURL,
                    kind: .userAgentMarkdown,
                    issues: &issues
                )
            )

            let skillDiscovery = discoverSkillDefinitions(
                scope: scope,
                rootScope: rootScope,
                skillsRootURL: skillsRootURL,
                skillDefinitionKind: .userSkillDefinition,
                skillDirectoryKind: .userSkillDirectory,
                issues: &issues
            )
            files.append(contentsOf: skillDiscovery.files)
            directories.append(contentsOf: skillDiscovery.directories)

            directories.append(
                contentsOf: discoverUserMemoryDirectories(
                    scope: scope,
                    rootScope: rootScope,
                    projectsRootURL: projectsRootURL,
                    issues: &issues
                )
            )
        }

        return DiscoveredWorkspace(
            scope: scope,
            rootScope: rootScope,
            rootURL: normalizedRootURL,
            rootNormalizedPath: rootNormalizedPath,
            rootAccessStatus: globalRoot.accessStatus,
            files: sortFiles(files),
            directories: sortDirectories(directories)
        )
    }

    private func scanProjectWorkspace(
        projectRoot: ResolvedProjectRoot,
        issues: inout [DiscoveryIssue]
    ) -> DiscoveredWorkspace {
        let rootScope = RootResolutionScope.projectRoot(projectID: projectRoot.reference.id)
        let normalizedRootURL = RootLocator.normalizedDirectoryURL(projectRoot.rootURL)
        let rootNormalizedPath = RootLocator.normalizedIdentityPath(normalizedRootURL.path)
        let scope = DiscoveryScopeIdentity.project(
            projectID: projectRoot.reference.id,
            normalizedProjectRootPath: rootNormalizedPath
        )

        var files: [DiscoveredFile] = []
        var directories: [DiscoveredDirectory] = []

        let claudeDirectoryURL = normalizedRootURL.appendingPathComponent(".claude", isDirectory: true)
        let settingsURL = claudeDirectoryURL.appendingPathComponent("settings.json", isDirectory: false)
        let settingsLocalURL = claudeDirectoryURL.appendingPathComponent("settings.local.json", isDirectory: false)
        let mcpURL = normalizedRootURL.appendingPathComponent(".mcp.json", isDirectory: false)
        let projectClaudeMarkdownURL = normalizedRootURL.appendingPathComponent("CLAUDE.md", isDirectory: false)
        let claudeDirectoryMarkdownURL = claudeDirectoryURL.appendingPathComponent("CLAUDE.md", isDirectory: false)
        let agentsRootURL = claudeDirectoryURL.appendingPathComponent("agents", isDirectory: true)
        let skillsRootURL = claudeDirectoryURL.appendingPathComponent("skills", isDirectory: true)

        directories.append(discoveredDirectory(scope: scope, kind: .projectRoot, url: normalizedRootURL, provenance: .canonicalExpected))
        directories.append(discoveredDirectory(scope: scope, kind: .projectClaudeDirectory, url: claudeDirectoryURL, provenance: .canonicalExpected))
        directories.append(discoveredDirectory(scope: scope, kind: .projectAgentsRoot, url: agentsRootURL, provenance: .canonicalExpected))
        directories.append(discoveredDirectory(scope: scope, kind: .projectSkillsRoot, url: skillsRootURL, provenance: .canonicalExpected))

        files.append(discoveredFile(scope: scope, kind: .projectSettingsJSON, url: settingsURL, provenance: .canonicalExpected))
        files.append(discoveredFile(scope: scope, kind: .projectSettingsLocalJSON, url: settingsLocalURL, provenance: .canonicalExpected))
        files.append(discoveredFile(scope: scope, kind: .projectMCPJSON, url: mcpURL, provenance: .canonicalExpected))
        files.append(discoveredFile(scope: scope, kind: .projectClaudeMarkdown, url: projectClaudeMarkdownURL, provenance: .canonicalExpected))
        files.append(discoveredFile(scope: scope, kind: .projectClaudeDotMarkdown, url: claudeDirectoryMarkdownURL, provenance: .canonicalExpected))

        if projectRoot.accessStatus == .accessible {
            files.append(
                contentsOf: discoverAgentMarkdownFiles(
                    scope: scope,
                    rootScope: rootScope,
                    rootURL: agentsRootURL,
                    kind: .projectAgentMarkdown,
                    issues: &issues
                )
            )

            let skillDiscovery = discoverSkillDefinitions(
                scope: scope,
                rootScope: rootScope,
                skillsRootURL: skillsRootURL,
                skillDefinitionKind: .projectSkillDefinition,
                skillDirectoryKind: .projectSkillDirectory,
                issues: &issues
            )
            files.append(contentsOf: skillDiscovery.files)
            directories.append(contentsOf: skillDiscovery.directories)
        }

        return DiscoveredWorkspace(
            scope: scope,
            rootScope: rootScope,
            rootURL: normalizedRootURL,
            rootNormalizedPath: rootNormalizedPath,
            rootAccessStatus: projectRoot.accessStatus,
            files: sortFiles(files),
            directories: sortDirectories(directories)
        )
    }

    private func discoverAgentMarkdownFiles(
        scope: DiscoveryScopeIdentity,
        rootScope: RootResolutionScope,
        rootURL: URL,
        kind: DiscoveredFileKind,
        issues: inout [DiscoveryIssue]
    ) -> [DiscoveredFile] {
        guard discoveredDirectoryStatus(at: rootURL) == .present else {
            return []
        }

        let traversal = traverseRecursively(from: rootURL, scope: scope, rootScope: rootScope, issues: &issues)

        return traversal.files
            .filter { $0.pathExtension.lowercased() == "md" }
            .map { discoveredFile(scope: scope, kind: kind, url: $0, provenance: .descendantDiscovered) }
    }

    private func discoverSkillDefinitions(
        scope: DiscoveryScopeIdentity,
        rootScope: RootResolutionScope,
        skillsRootURL: URL,
        skillDefinitionKind: DiscoveredFileKind,
        skillDirectoryKind: DiscoveredDirectoryKind,
        issues: inout [DiscoveryIssue]
    ) -> (files: [DiscoveredFile], directories: [DiscoveredDirectory]) {
        guard discoveredDirectoryStatus(at: skillsRootURL) == .present else {
            return ([], [])
        }

        let traversal = traverseRecursively(from: skillsRootURL, scope: scope, rootScope: rootScope, issues: &issues)

        let directories = traversal.directories
            .map { discoveredDirectory(scope: scope, kind: skillDirectoryKind, url: $0, provenance: .descendantDiscovered) }

        let files = traversal.files
            .filter { $0.lastPathComponent.lowercased() == "skill.md" }
            .map { discoveredFile(scope: scope, kind: skillDefinitionKind, url: $0, provenance: .descendantDiscovered) }

        return (files, directories)
    }

    private func discoverUserMemoryDirectories(
        scope: DiscoveryScopeIdentity,
        rootScope: RootResolutionScope,
        projectsRootURL: URL,
        issues: inout [DiscoveryIssue]
    ) -> [DiscoveredDirectory] {
        guard discoveredDirectoryStatus(at: projectsRootURL) == .present else {
            return []
        }

        let projectFolders = readDirectorySafely(at: projectsRootURL, scope: scope, rootScope: rootScope, issues: &issues)
            .filter { fileSystem.nodeKind(at: $0) == .directory }
            .sorted { normalizedPath(for: $0) < normalizedPath(for: $1) }

        return projectFolders.map { projectFolderURL in
            let memoryURL = projectFolderURL.appendingPathComponent("memory", isDirectory: true)
            return discoveredDirectory(scope: scope, kind: .userProjectMemoryDirectory, url: memoryURL, provenance: .descendantDiscovered)
        }
    }

    private func traverseRecursively(
        from rootURL: URL,
        scope: DiscoveryScopeIdentity,
        rootScope: RootResolutionScope,
        issues: inout [DiscoveryIssue]
    ) -> (files: [URL], directories: [URL]) {
        var files: [URL] = []
        var directories: [URL] = []
        var queue: [URL] = [RootLocator.normalizedDirectoryURL(rootURL)]

        while let currentDirectory = queue.first {
            queue.removeFirst()

            let children = readDirectorySafely(at: currentDirectory, scope: scope, rootScope: rootScope, issues: &issues)
                .sorted { normalizedPath(for: $0) < normalizedPath(for: $1) }

            for child in children {
                switch fileSystem.nodeKind(at: child) {
                case .directory:
                    directories.append(child)
                    queue.append(child)
                case .file:
                    if !fileSystem.isReadable(at: child) {
                        issues.append(
                            DiscoveryIssue(
                                code: .scanDescendantInaccessible,
                                severity: .warning,
                                target: .scanOperation(scope: scope, path: child.path),
                                message: "A discovered file is not readable. Scan results are partial.",
                                path: child.path,
                                scope: rootScope
                            )
                        )
                    }
                    files.append(child)
                case .inaccessible:
                    issues.append(
                        DiscoveryIssue(
                            code: .scanDescendantInaccessible,
                            severity: .warning,
                            target: .scanOperation(scope: scope, path: child.path),
                            message: "A discovered descendant path is not readable. Scan results are partial.",
                            path: child.path,
                            scope: rootScope
                        )
                    )
                case .missing:
                    break
                }
            }
        }

        return (files, directories)
    }

    private func readDirectorySafely(
        at url: URL,
        scope: DiscoveryScopeIdentity,
        rootScope: RootResolutionScope,
        issues: inout [DiscoveryIssue]
    ) -> [URL] {
        do {
            return try fileSystem.contentsOfDirectory(at: url)
                .map { RootLocator.normalizedDirectoryURL($0) }
        } catch {
            issues.append(
                DiscoveryIssue(
                    code: .scanDirectoryEnumerationFailed,
                    severity: .warning,
                    target: .scanOperation(scope: scope, path: url.path),
                    message: "A directory could not be enumerated during discovery. Scan results are partial.",
                    path: url.path,
                    diagnostics: String(describing: error),
                    scope: rootScope
                )
            )
            return []
        }
    }

    private func discoveredFile(
        scope: DiscoveryScopeIdentity,
        kind: DiscoveredFileKind,
        url: URL,
        provenance: DiscoveryPathProvenance
    ) -> DiscoveredFile {
        DiscoveredFile(
            scope: scope,
            kind: kind,
            url: url,
            provenance: provenance,
            status: discoveredFileStatus(at: url)
        )
    }

    private func discoveredDirectory(
        scope: DiscoveryScopeIdentity,
        kind: DiscoveredDirectoryKind,
        url: URL,
        provenance: DiscoveryPathProvenance
    ) -> DiscoveredDirectory {
        DiscoveredDirectory(
            scope: scope,
            kind: kind,
            url: url,
            provenance: provenance,
            status: discoveredDirectoryStatus(at: url)
        )
    }

    private func discoveredFileStatus(at url: URL) -> DiscoveryPathStatus {
        switch fileSystem.nodeKind(at: url) {
        case .missing:
            return .missing
        case .file:
            return fileSystem.isReadable(at: url) ? .present : .unreadable
        case .directory:
            return .unsupported
        case .inaccessible:
            return .inaccessible
        }
    }

    private func discoveredDirectoryStatus(at url: URL) -> DiscoveryPathStatus {
        switch fileSystem.nodeKind(at: url) {
        case .missing:
            return .missing
        case .directory:
            return fileSystem.isReadable(at: url) ? .present : .unreadable
        case .file:
            return .unsupported
        case .inaccessible:
            return .inaccessible
        }
    }

    private func sortFiles(_ files: [DiscoveredFile]) -> [DiscoveredFile] {
        files.sorted {
            if $0.scope.stableIdentifier != $1.scope.stableIdentifier {
                return $0.scope.stableIdentifier < $1.scope.stableIdentifier
            }
            if $0.normalizedPath != $1.normalizedPath {
                return $0.normalizedPath < $1.normalizedPath
            }
            if $0.kind.rawValue != $1.kind.rawValue {
                return $0.kind.rawValue < $1.kind.rawValue
            }
            return $0.id.rawValue < $1.id.rawValue
        }
    }

    private func sortDirectories(_ directories: [DiscoveredDirectory]) -> [DiscoveredDirectory] {
        directories.sorted {
            if $0.scope.stableIdentifier != $1.scope.stableIdentifier {
                return $0.scope.stableIdentifier < $1.scope.stableIdentifier
            }
            if $0.normalizedPath != $1.normalizedPath {
                return $0.normalizedPath < $1.normalizedPath
            }
            if $0.kind.rawValue != $1.kind.rawValue {
                return $0.kind.rawValue < $1.kind.rawValue
            }
            return $0.id.rawValue < $1.id.rawValue
        }
    }

    private func deduplicateAndSortIssues(_ issues: [DiscoveryIssue]) -> [DiscoveryIssue] {
        let unique = Dictionary(grouping: issues, by: \.id)
            .compactMap { $0.value.first }

        return unique.sorted {
            if $0.id == $1.id {
                return $0.message < $1.message
            }
            return $0.id < $1.id
        }
    }

    private func normalizedPath(for url: URL) -> String {
        RootLocator.normalizedIdentityPath(url.path)
    }
}

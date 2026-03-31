import Foundation

typealias DiscoveredPathStatus = DiscoveryPathStatus

enum DiscoveredFileKind: String, Equatable, Sendable {
    case managedSettingsJSON
    case managedSettingsDropIn
    case managedMcpJSON
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
    case managedSettingsRoot
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
    let managedWorkspace: DiscoveredWorkspace?
    let userWorkspace: DiscoveredWorkspace?
    let projectWorkspaces: [DiscoveredWorkspace]
    let issues: [DiscoveryIssue]
}

protocol ManagedSettingsFileSystem {
    func fileExists(atPath: String) -> Bool
    func isReadable(atPath: String) -> Bool
    func contentsOfDirectory(atPath: String, error: inout NSError?) -> [String]
    func fileExists(atPath: String, isDirectory: inout ObjCBool) -> Bool
}

struct DefaultManagedSettingsFileSystem: ManagedSettingsFileSystem {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func fileExists(atPath: String) -> Bool {
        fileManager.fileExists(atPath: atPath)
    }

    func isReadable(atPath: String) -> Bool {
        fileManager.isReadableFile(atPath: atPath)
    }

    func contentsOfDirectory(atPath: String, error: inout NSError?) -> [String] {
        do {
            return try fileManager.contentsOfDirectory(atPath: atPath)
        } catch let nsError as NSError {
            error = nsError
            return []
        } catch let unexpectedError {
            error = NSError(
                domain: "DefaultManagedSettingsFileSystem",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: String(describing: unexpectedError)]
            )
            return []
        }
    }

    func fileExists(atPath: String, isDirectory: inout ObjCBool) -> Bool {
        fileManager.fileExists(atPath: atPath, isDirectory: &isDirectory)
    }
}

private enum ManagedSettingsNodeStatus: Equatable, Sendable {
    case missing
    case readableFile
    case readableDirectory
    case unreadableFile
    case unreadableDirectory
    case unsupported

    var discoveryPathStatus: DiscoveryPathStatus {
        switch self {
        case .missing:
            return .missing
        case .readableFile, .readableDirectory:
            return .present
        case .unreadableFile, .unreadableDirectory:
            return .unreadable
        case .unsupported:
            return .unsupported
        }
    }
}

private struct ManagedSettingsDiscoveryFile: Equatable, Sendable {
    let url: URL
    let status: ManagedSettingsNodeStatus
}

private struct ManagedSettingsDiscoverySnapshot {
    let rootURL: URL
    let rootStatus: ManagedSettingsNodeStatus
    let settingsFile: ManagedSettingsDiscoveryFile
    let dropInDirectoryURL: URL
    let dropInDirectoryStatus: ManagedSettingsNodeStatus
    let dropInEnumerationErrorDescription: String?
    let dropInFiles: [ManagedSettingsDiscoveryFile]
    let mcpFile: ManagedSettingsDiscoveryFile
}

struct ManagedSettingsLocator {
    static let managedRootPath = "/Library/Application Support/ClaudeCode"
    static let managedSettingsFileName = "managed-settings.json"
    static let managedSettingsDropInDirectoryName = "managed-settings.d"
    static let managedMcpFileName = "managed-mcp.json"

    private let fileSystem: ManagedSettingsFileSystem

    init(fileSystem: ManagedSettingsFileSystem = DefaultManagedSettingsFileSystem()) {
        self.fileSystem = fileSystem
    }

    func locateManagedSettingsFile() -> URL? {
        let snapshot = discoverySnapshot()
        guard snapshot.settingsFile.status == .readableFile else {
            return nil
        }
        return snapshot.settingsFile.url
    }

    func locateManagedSettingsDirectory() -> [URL] {
        discoverySnapshot().dropInFiles
            .filter { $0.status == .readableFile }
            .map(\.url)
    }

    func locateManagedMcpFile() -> URL? {
        let snapshot = discoverySnapshot()
        guard snapshot.mcpFile.status == .readableFile else {
            return nil
        }
        return snapshot.mcpFile.url
    }

    fileprivate func discoverySnapshot() -> ManagedSettingsDiscoverySnapshot {
        let rootURL = URL(fileURLWithPath: Self.managedRootPath, isDirectory: true)
        let settingsURL = rootURL.appendingPathComponent(Self.managedSettingsFileName, isDirectory: false)
        let dropInDirectoryURL = rootURL.appendingPathComponent(Self.managedSettingsDropInDirectoryName, isDirectory: true)
        let mcpURL = rootURL.appendingPathComponent(Self.managedMcpFileName, isDirectory: false)

        let rootStatus = nodeStatus(at: rootURL.path, expectsDirectory: true)
        let settingsStatus = nodeStatus(at: settingsURL.path, expectsDirectory: false)
        let dropInDirectoryStatus = nodeStatus(at: dropInDirectoryURL.path, expectsDirectory: true)
        let mcpStatus = nodeStatus(at: mcpURL.path, expectsDirectory: false)

        var dropInError: NSError?
        var dropInFiles: [ManagedSettingsDiscoveryFile] = []

        if dropInDirectoryStatus == .readableDirectory {
            let entries = fileSystem.contentsOfDirectory(atPath: dropInDirectoryURL.path, error: &dropInError)
                .filter { $0.lowercased().hasSuffix(".json") }
                .sorted()

            dropInFiles = entries.map { entry in
                let fileURL = dropInDirectoryURL.appendingPathComponent(entry, isDirectory: false)
                return ManagedSettingsDiscoveryFile(url: fileURL, status: nodeStatus(at: fileURL.path, expectsDirectory: false))
            }
        }

        return ManagedSettingsDiscoverySnapshot(
            rootURL: rootURL,
            rootStatus: rootStatus,
            settingsFile: ManagedSettingsDiscoveryFile(url: settingsURL, status: settingsStatus),
            dropInDirectoryURL: dropInDirectoryURL,
            dropInDirectoryStatus: dropInDirectoryStatus,
            dropInEnumerationErrorDescription: dropInError.map(String.init(describing:)),
            dropInFiles: dropInFiles,
            mcpFile: ManagedSettingsDiscoveryFile(url: mcpURL, status: mcpStatus)
        )
    }

    private func nodeStatus(at path: String, expectsDirectory: Bool) -> ManagedSettingsNodeStatus {
        var isDirectory = ObjCBool(false)
        let exists = fileSystem.fileExists(atPath: path, isDirectory: &isDirectory)

        guard exists else {
            return .missing
        }

        guard isDirectory.boolValue == expectsDirectory else {
            return .unsupported
        }

        let readable = fileSystem.isReadable(atPath: path)
        if expectsDirectory {
            return readable ? .readableDirectory : .unreadableDirectory
        }

        return readable ? .readableFile : .unreadableFile
    }
}

// MARK: - M4: Sandbox entitlements and managed access fallback

/// Outcome of probing whether the managed ClaudeCode path is accessible in this process.
///
/// In a sandboxed macOS App Store build the OS may hide `/Library/Application Support/ClaudeCode/`
/// entirely (returning ENOENT) even when the directory exists, so the app must distinguish that
/// case from a genuine absence of managed configuration and surface it explicitly rather than
/// silently treating it as "no policy".
enum ManagedAccessOutcome: Equatable, Sendable {
    /// Root directory is readable; managed files may be present.
    case accessible
    /// Root directory does not exist in the filesystem; no managed config has been deployed.
    case missing
    /// Access to the managed root was blocked by macOS sandbox policy. The directory may or may
    /// not exist on disk — the sandbox prevents the app from observing it.
    case sandboxRestricted
    /// Root directory exists but could not be read for a non-sandbox reason (e.g. wrong
    /// permissions, unexpected node type).
    case inaccessible(diagnostics: String?)

    /// True when the outcome requires an explicit fallback message in the UI rather than just
    /// treating managed scope as absent.
    var requiresExplicitFallbackUI: Bool {
        switch self {
        case .accessible, .missing:
            return false
        case .sandboxRestricted, .inaccessible:
            return true
        }
    }
}

// MARK: - Sandbox detection

/// Abstracts sandbox detection so that it can be replaced by a test double.
protocol SandboxProbing: Sendable {
    /// True when the current process is running inside a macOS App Sandbox container.
    var isRunningInSandbox: Bool { get }
}

/// Production implementation that reads the `APP_SANDBOX_CONTAINER_ID` environment variable,
/// which the OS sets for every sandboxed process.
struct SystemSandboxProbe: SandboxProbing {
    var isRunningInSandbox: Bool {
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }
}

// MARK: - ManagedSettingsLocator probe

extension ManagedSettingsLocator {
    /// Returns the concrete access outcome for the managed ClaudeCode root path.
    ///
    /// - Parameter sandboxProbe: A `SandboxProbing` implementation used to determine whether the
    ///   process is running inside a sandbox. Defaults to the system implementation.
    /// - Returns: The `ManagedAccessOutcome` describing whether managed files can be read.
    func probeManagedAccessOutcome(
        sandboxProbe: SandboxProbing = SystemSandboxProbe()
    ) -> ManagedAccessOutcome {
        let snapshot = discoverySnapshot()

        switch snapshot.rootStatus {
        case .readableDirectory:
            return .accessible

        case .unreadableDirectory:
            // The directory exists but cannot be read.
            if sandboxProbe.isRunningInSandbox {
                return .sandboxRestricted
            }
            return .inaccessible(
                diagnostics: "Managed root directory exists but is not readable by this process."
            )

        case .missing:
            // In a sandbox, paths outside the container appear absent even when they exist on
            // disk; we cannot distinguish genuine absence from sandbox-hidden presence.
            if sandboxProbe.isRunningInSandbox {
                return .sandboxRestricted
            }
            return .missing

        case .readableFile, .unreadableFile:
            return .inaccessible(
                diagnostics: "Expected a directory at the managed root path but found a file."
            )

        case .unsupported:
            return .inaccessible(
                diagnostics: "Managed root path has an unexpected filesystem node type."
            )
        }
    }
}

protocol MDMPolicyReading {
    func readPolicies() -> ParseResult<[String: JSONValue]>
}

struct MDMPolicyReader: MDMPolicyReading {
    static let managedPolicyDomain = "com.anthropic.claudecode"

    private let userDefaultsReader: () -> [String: Any]?
    private let cfPreferencesReader: () -> [String: Any]?

    init() {
        self.userDefaultsReader = { Self.readPoliciesFromUserDefaults() }
        self.cfPreferencesReader = { Self.readPoliciesFromCFPreferences() }
    }

    init(
        userDefaultsReader: @escaping () -> [String: Any]?,
        cfPreferencesReader: @escaping () -> [String: Any]? = { nil }
    ) {
        self.userDefaultsReader = userDefaultsReader
        self.cfPreferencesReader = cfPreferencesReader
    }

    func readPolicies() -> ParseResult<[String: JSONValue]> {
        let rawPolicies = readFromUserDefaults() ?? readFromCFPreferences() ?? [:]
        var issues: [SyntaxIssue] = []
        var converted: [String: JSONValue] = [:]

        for key in rawPolicies.keys.sorted() {
            guard let rawValue = rawPolicies[key] else {
                continue
            }

            if let value = convertToJSONValue(rawValue, keyPath: key, issues: &issues) {
                converted[key] = value
            }
        }

        return ParseResult(value: converted, issues: issues)
    }

    private func convertToJSONValue(_ value: Any) -> JSONValue? {
        var issues: [SyntaxIssue] = []
        return convertToJSONValue(value, keyPath: nil, issues: &issues)
    }

    private func convertToJSONValue(
        _ value: Any,
        keyPath: String?,
        issues: inout [SyntaxIssue]
    ) -> JSONValue? {
        switch value {
        case let stringValue as String:
            return .string(stringValue)
        case let numberValue as NSNumber:
            if CFGetTypeID(numberValue) == CFBooleanGetTypeID() {
                return .bool(numberValue.boolValue)
            }
            return .number(numberValue.doubleValue)
        case let boolValue as Bool:
            return .bool(boolValue)
        case let dictionary as [String: Any]:
            var object: [String: JSONValue] = [:]
            for key in dictionary.keys.sorted() {
                guard let nestedValue = dictionary[key] else {
                    continue
                }

                let nestedKeyPath = keyPath.map { "\($0).\(key)" } ?? key
                if let convertedValue = convertToJSONValue(nestedValue, keyPath: nestedKeyPath, issues: &issues) {
                    object[key] = convertedValue
                }
            }
            return .object(object)
        case let dictionary as NSDictionary:
            var object: [String: JSONValue] = [:]
            for case let key as String in dictionary.allKeys.sorted(by: { "\($0)" < "\($1)" }) {
                let nestedKeyPath = keyPath.map { "\($0).\(key)" } ?? key
                if let nestedValue = dictionary[key],
                   let convertedValue = convertToJSONValue(nestedValue, keyPath: nestedKeyPath, issues: &issues) {
                    object[key] = convertedValue
                }
            }
            return .object(object)
        case let array as [Any]:
            return .array(
                array.enumerated().compactMap { index, element in
                    let nestedKeyPath = keyPath.map { "\($0)[\(index)]" } ?? "[\(index)]"
                    return convertToJSONValue(element, keyPath: nestedKeyPath, issues: &issues)
                }
            )
        case let array as NSArray:
            return .array(
                array.enumerated().compactMap { index, element in
                    let nestedKeyPath = keyPath.map { "\($0)[\(index)]" } ?? "[\(index)]"
                    return convertToJSONValue(element, keyPath: nestedKeyPath, issues: &issues)
                }
            )
        case _ as NSNull:
            return .null
        case _ as Data:
            appendUnsupportedTypeIssue(typeName: "NSData", keyPath: keyPath, issues: &issues)
            return nil
        case _ as Date:
            appendUnsupportedTypeIssue(typeName: "NSDate", keyPath: keyPath, issues: &issues)
            return nil
        default:
            appendUnsupportedTypeIssue(
                typeName: String(describing: type(of: value)),
                keyPath: keyPath,
                issues: &issues
            )
            return nil
        }
    }

    private func appendUnsupportedTypeIssue(
        typeName: String,
        keyPath: String?,
        issues: inout [SyntaxIssue]
    ) {
        let keyDescriptor = keyPath ?? "<root>"
        issues.append(
            SyntaxIssue(
                code: .preservedUnknownValue,
                severity: .info,
                message: "MDM key '\(keyDescriptor)' has unsupported plist type \(typeName)",
                sourcePath: Self.managedPolicyDomain,
                keyPath: keyPath
            )
        )
    }

    private func readFromUserDefaults() -> [String: Any]? {
        userDefaultsReader()
    }

    private func readFromCFPreferences() -> [String: Any]? {
        cfPreferencesReader()
    }

    private static func readPoliciesFromUserDefaults() -> [String: Any]? {
        guard let defaults = UserDefaults(suiteName: managedPolicyDomain) else {
            return nil
        }

        if let persistentDomain = defaults.persistentDomain(forName: managedPolicyDomain),
           !persistentDomain.isEmpty {
            return persistentDomain
        }

        let dictionaryRepresentation = defaults.dictionaryRepresentation()
        return dictionaryRepresentation.isEmpty ? nil : dictionaryRepresentation
    }

    private static func readPoliciesFromCFPreferences() -> [String: Any]? {
        readPoliciesFromCFPreferences(user: kCFPreferencesAnyUser, host: kCFPreferencesCurrentHost) ??
        readPoliciesFromCFPreferences(user: kCFPreferencesAnyUser, host: kCFPreferencesAnyHost)
    }

    private static func readPoliciesFromCFPreferences(
        user: CFString,
        host: CFString
    ) -> [String: Any]? {
        guard let keyList = CFPreferencesCopyKeyList(
            managedPolicyDomain as CFString,
            user,
            host
        ) as? [String],
        !keyList.isEmpty,
        let values = CFPreferencesCopyMultiple(
            keyList as CFArray,
            managedPolicyDomain as CFString,
            user,
            host
        ) as? [String: Any],
        !values.isEmpty else {
            return nil
        }

        return values
    }
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
    private let managedSettingsLocator: ManagedSettingsLocator
    private let homeDirectoryProvider: () -> URL

    init(
        fileSystem: WorkspaceScanningFileSystem = FileManagerWorkspaceScanningFileSystem(),
        managedSettingsLocator: ManagedSettingsLocator = ManagedSettingsLocator(),
        homeDirectoryProvider: @escaping () -> URL = { FileManager.default.homeDirectoryForCurrentUser }
    ) {
        self.fileSystem = fileSystem
        self.managedSettingsLocator = managedSettingsLocator
        self.homeDirectoryProvider = homeDirectoryProvider
    }

    func scan(_ request: ScanRequest) -> ScanResult {
        var issues = request.rootResolution.issues
        let managedWorkspace = scanManagedWorkspace(issues: &issues)

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
            managedWorkspace: managedWorkspace,
            userWorkspace: userWorkspace,
            projectWorkspaces: projectWorkspaces,
            issues: deduplicateAndSortIssues(issues)
        )
    }

    private func scanManagedWorkspace(
        issues: inout [DiscoveryIssue]
    ) -> DiscoveredWorkspace {
        let managedRootURL = RootLocator.normalizedDirectoryURL(
            URL(fileURLWithPath: ManagedSettingsLocator.managedRootPath, isDirectory: true)
        )
        let managedRootPath = RootLocator.normalizedIdentityPath(managedRootURL.path)
        let managedScope = DiscoveryScopeIdentity.managed()
        let managedRootScope = RootResolutionScope.managedRoot
        let discovery = scanManagedSettingsScope(issues: &issues)
        let rootStatus = discovery.directories.first(where: { $0.kind == .managedSettingsRoot })?.status ?? .missing

        return DiscoveredWorkspace(
            scope: managedScope,
            rootScope: managedRootScope,
            rootURL: managedRootURL,
            rootNormalizedPath: managedRootPath,
            rootAccessStatus: rootAccessStatus(for: rootStatus),
            files: sortFiles(discovery.files),
            directories: sortDirectories(discovery.directories)
        )
    }

    private func scanManagedSettingsScope(
        issues: inout [DiscoveryIssue]
    ) -> (files: [DiscoveredFile], directories: [DiscoveredDirectory]) {
        let scope = DiscoveryScopeIdentity.managed()
        let snapshot = managedSettingsLocator.discoverySnapshot()

        var files: [DiscoveredFile] = []
        var directories: [DiscoveredDirectory] = []

        directories.append(
            DiscoveredDirectory(
                scope: scope,
                kind: .managedSettingsRoot,
                url: snapshot.rootURL,
                provenance: .canonicalExpected,
                status: snapshot.rootStatus.discoveryPathStatus
            )
        )

        files.append(
            discoveredManagedFile(scope: scope, kind: .managedSettingsJSON, file: snapshot.settingsFile)
        )
        files.append(
            discoveredManagedFile(scope: scope, kind: .managedMcpJSON, file: snapshot.mcpFile)
        )
        files.append(
            contentsOf: snapshot.dropInFiles.map {
                discoveredManagedFile(scope: scope, kind: .managedSettingsDropIn, file: $0)
            }
        )

        appendManagedDiscoveryIssues(from: snapshot, scope: scope, issues: &issues)

        return (files, directories)
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

    private func discoveredManagedFile(
        scope: DiscoveryScopeIdentity,
        kind: DiscoveredFileKind,
        file: ManagedSettingsDiscoveryFile
    ) -> DiscoveredFile {
        DiscoveredFile(
            scope: scope,
            kind: kind,
            url: file.url,
            provenance: .canonicalExpected,
            status: file.status.discoveryPathStatus
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

    private func rootAccessStatus(for status: DiscoveryPathStatus) -> RootAccessStatus {
        switch status {
        case .present:
            return .accessible
        case .missing:
            return .missing
        case .unreadable, .inaccessible:
            return .inaccessible
        case .unsupported:
            return .notDirectory
        }
    }

    private func appendManagedDiscoveryIssues(
        from snapshot: ManagedSettingsDiscoverySnapshot,
        scope: DiscoveryScopeIdentity,
        issues: inout [DiscoveryIssue]
    ) {
        if snapshot.rootStatus == .unreadableDirectory || snapshot.rootStatus == .unsupported {
            issues.append(
                DiscoveryIssue(
                    code: .managedSettingsRootInaccessible,
                    severity: .warning,
                    target: .workspace(scope: scope),
                    message: "The managed ClaudeCode root exists but is not readable.",
                    path: snapshot.rootURL.path,
                    scope: .managedRoot
                )
            )
        }

        if snapshot.dropInDirectoryStatus == .unreadableDirectory || snapshot.dropInDirectoryStatus == .unsupported {
            issues.append(
                DiscoveryIssue(
                    code: .managedSettingsDropInInaccessible,
                    severity: .warning,
                    target: .scanOperation(scope: scope, path: snapshot.dropInDirectoryURL.path),
                    message: "The managed settings drop-in directory exists but could not be read.",
                    path: snapshot.dropInDirectoryURL.path,
                    scope: .managedRoot
                )
            )
        }

        if let enumerationError = snapshot.dropInEnumerationErrorDescription {
            issues.append(
                DiscoveryIssue(
                    code: .managedSettingsDropInEnumerationFailed,
                    severity: .warning,
                    target: .scanOperation(scope: scope, path: snapshot.dropInDirectoryURL.path),
                    message: "The managed settings drop-in directory could not be enumerated.",
                    path: snapshot.dropInDirectoryURL.path,
                    diagnostics: String(describing: enumerationError),
                    scope: .managedRoot
                )
            )
        }

        let unreadableFiles = [snapshot.settingsFile, snapshot.mcpFile] + snapshot.dropInFiles.filter { $0.status == .unreadableFile }
        for file in unreadableFiles where file.status == .unreadableFile {
            issues.append(
                DiscoveryIssue(
                    code: .managedSettingsFileUnreadable,
                    severity: .warning,
                    target: .file(pathID: DiscoveryPathID(normalizedPath: RootLocator.normalizedIdentityPath(file.url.path), scope: scope, nodeClass: .file)),
                    message: "A managed Claude configuration file exists but is not readable.",
                    path: file.url.path,
                    scope: .managedRoot
                )
            )
        }
    }
}
